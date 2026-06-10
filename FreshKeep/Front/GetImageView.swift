//
//  ContentView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/11/26.
//

import SwiftUI
import PhotosUI
import SwiftData
import StoreKit

struct GetImageView: View {
    @Query(filter: #Predicate<FoodItem> { $0.isConsumed == false })
    var allFoods: [FoodItem]
    
    @StateObject private var navManager = NavigationManager()
    
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotosPicker = false
    @State private var selectedItem: PhotosPickerItem? = nil
    
    @State private var capturedImage: UIImage? = nil
    @State private var navigateToShowImageView = false
    
    // 구매 복원 vars
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    @Environment(\.modelContext) private var modelContext: ModelContext
    var body: some View {
        NavigationStack(path: $navManager.path){
            ZStack{
                Color(red: 0.1, green: 0.1, blue: 0.15).ignoresSafeArea()
                // 상단의 헤더 (지우는게 이쁠지도)
                VStack{
                    headerView
                    Spacer()
                    mainButtonView// 카메라/갤러리 버튼
                    Spacer()
                    bottomButtonsView// 하단
                }
                .padding()
            }
            // 사진이 획득되면 ShowImageView로 이동
            .navigationDestination(for: AppDestination.self) { value in
                destinationView(for: value)
            }
            // 선택지 (카메라 or 갤러리)
            .confirmationDialog("식재료 등록하기", isPresented: $showActionSheet){
                Button("사진 촬영"){ showCamera = true }
                Button("갤러리에서 선택"){
                    showPhotosPicker = true
                    print("갤러리 선택 click")
                }
                Button("취소", role: .cancel){}
            }
            // 갤러리 호출
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedItem, matching: .images)
            // 카메라 호출
            .fullScreenCover(isPresented: $showCamera){
                CameraPicker(image: $capturedImage)
            }
            .onChange(of: capturedImage) { _, newImage in
                if newImage != nil {
                    navManager.path.append(.showImage(mainImage: newImage!))
                }
            }
            // 갤러리에서 사진이 선택됨을 감지
            .onChange(of: selectedItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            self.capturedImage = uiImage
                        }
                    }
                }
            }
            // 구매 복원 시 알림 호출
            .alert("알림", isPresented: $showAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear { NotificationManager.shared.updateFoodNotifications(allFoodList: allFoods) }
        }
    }
        
    func resetAllData(modelContext: ModelContext) {
        do {
            try modelContext.delete(model: FoodItem.self)
            try modelContext.delete(model: Category.self)
            try modelContext.delete(model: CaptureSession.self)
            
            // 2. ⚠️ 가장 중요한 포인트: 명시적 저장
            // 이걸 안 해주면 메모리 상에만 삭제되고 실제 DB 파일에는 반영이 늦어질 수 있어요.
            try modelContext.save()
            print("✅ 모든 데이터가 초기화되었습니다.")
        } catch {
            print("❌ 초기화 중 에러 발생: \(error)")
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .showImage(let image, _):
            ShowImageView(mainImage: image)
                .environmentObject(navManager)
        case .gptResult:
            EmptyView()
        case .refrigerator:
            MyRefrigeratorView()
                .environmentObject(navManager)
        case .store: // consumed food listup을 위한 testView
            MyStoreSheetView()
                .environmentObject(navManager)
        case .geminiResult:
            GeminiResultView(mainImage: capturedImage!)
                .environmentObject(navManager)
        case .smartRecipe:
            SelectFoodsView()
                .environmentObject(navManager)
        case .recipeOption(let selectedFoods):
            RecipeOptionView(selectedFoods: .constant(selectedFoods.foods))
                .environmentObject(navManager)
        case .geminiRecipe(let recipeOptions):
            ShowGeminiRecipeView(options: recipeOptions)
                .environmentObject(navManager)
        case .recipeList:
            RecipeListView()
                .environmentObject(navManager)
        case .savedRecipe(let recipe):
            ShowSavedRecipeView(recipe: recipe)
                .environmentObject(navManager)
        case .storeFull:
            MyStoreFullView()
                .environmentObject(navManager)
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    // 카메라 View 실행
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        
        // 카메라를 사용할 수 있는 기기인지 확인 (시뮬레이터 크래시 방지
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
    }
}

extension GetImageView {
    private var headerView: some View {
        HStack {
            Text("FreshKeep")
                .font(.title.bold())
                .foregroundColor(.white)
            Spacer()
            Menu {
                Button("프로모션 확인"){ // test View
                    navManager.path.append(.storeFull)
                    print("chk consumed food click")
                }.padding()
                
                Button("구매 복원") {
                    Task {
                        do {
                            // 1. 애플 서버와 동기화 (영수증 최신화)
                            try await AppStore.sync()
                            
                            // 2. 실제 상태 확인
                            await StoreManager.shared.updateStatus()
                            
                            // 3. (선택사항) 유저에게 알려주기
                            if StoreManager.shared.isPremium {
                                alertMessage = "구매 내역이 복원되었습니다."
                            } else {
                                alertMessage = "복원할 이전 내역이 없습니다."
                            }
                            showAlert = true
                            
                        } catch {
                            alertMessage = "복원 중 에러가 발생하였습니다."
                            showAlert = true
                        }
                    }
                }
            } label: {
                ZStack {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(Color.white)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    private var mainButtonView: some View {
        VStack{
            Button{
                showActionSheet = true
            } label: {
                ZStack {
                    // 은은한 글로우 효과 (파란색 빛)
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 220, height: 220)
                        .blur(radius: 10)
                    
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 180, height: 180)
                        .overlay(
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    
                    // 실제 카메라 아이콘
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
            }
            
            Text("식재료를 찍고 스마트하게 보관하세요")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    private var bottomButtonsView: some View {
        VStack(spacing: 12) {
            NavigationButton(title: String(localized: "내 냉장고"), subTitle: String(localized: "식재료 보관 중"))
                .onTapGesture {
                    navManager.path.append(.refrigerator)
                }
            
            HStack(spacing: 10){
                NavigationButton(title: String(localized: "스마트 레시피"), subTitle: String(localized: "AI로 레시피 만들기"))
                    .onTapGesture {
                        navManager.path.append(.smartRecipe)
                    }
                NavigationButton(title: String(localized: "레시피 리스트"), subTitle: String(localized: "저장한 레시피 확인"))
                    .onTapGesture {
                        navManager.path.append(.recipeList)
                    }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
}

#Preview {
    GetImageView()
}
