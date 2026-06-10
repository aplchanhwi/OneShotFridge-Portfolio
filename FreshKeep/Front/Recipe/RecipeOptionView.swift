//
//  RecipeOptionView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/13/26.
//

import SwiftUI
import SwiftData

struct RecipeOptionView: View {
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var storeManager: StoreManager
    @Binding var selectedFoods: [FoodItem]
    @State private var foodName: String = ""
    @State private var requiredFoodIDs: Set<UUID> = []
    @State private var selectedDifficulty: String = "보통"
    @State private var selectedCuisine = "한식"
    @State private var additionalRequests: String = ""
    @State private var isShowingAlert: Bool = false
    @State private var isShowingStore = false
    @State private var isAutoSuggestMode: Bool = true
    
    private let cuisineKeys = ["한식", "양식", "일식", "중식", "상관없음"]
    private let difficultyKeys = ["쉬움", "보통", "어려움"]
    private let charLimit = 100
    
    @State private var currentRecipeOptions: [String: String] = [:]
    
    var body: some View {
        List {
            Section {
                Picker("방식 선택", selection: $isAutoSuggestMode) {
                    Text("AI 추천받기").tag(true)
                    Text("직접 입력하기").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
                
                if isAutoSuggestMode {
                    Text("냉장고 재료를 바탕으로 요리를 추천해 드릴게요!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    HStack {
                        Text("요리 이름")
                        Spacer()
                        TextField("예: 김치찌개, 알리오올리오", text: $foodName)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } header: {
                Text("어떤 요리를 만들까요?") // 섹션 제목도 좀 더 부드럽게!
            }
            
            Section("필수로 넣을 재료") {
                ForEach(selectedFoods) { food in
                    Toggle(isOn: Binding(
                        // 화면의 토글 스위치의 on off 표시 여부를 requiredFoodIDs의 포함 여부에 따라 결정하고
                        get: { requiredFoodIDs.contains(food.id) },
                        // toggle switch를 탭 했을 때, on이면 insert off이면 remove 해라
                        set: { isTarget in
                            if isTarget {
                                requiredFoodIDs.insert(food.id)
                            } else {
                                requiredFoodIDs.remove(food.id)
                            }
                        }
                    )) {
                        Text(food.title)
                    }
                }
            }
            
            Section("요리 난이도") {
                Picker("난이도", selection: $selectedDifficulty) {
                    ForEach(difficultyKeys, id: \.self){ difficultyKey in
                        Text(String(localized: String.LocalizationValue(stringLiteral: difficultyKey)))
                    }
                }
                .pickerStyle(.palette)
            }
            
            if foodName.isEmpty{
                Section("요리 스타일") {
                    Picker("스타일", selection: $selectedCuisine) {
                        ForEach(cuisineKeys, id: \.self){ cuisineKey in
                            Text(String(localized: String.LocalizationValue(stringLiteral: cuisineKey)))
                        }
                    }.pickerStyle(.palette)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Section(header: Text("기타 요구사항"), footer: Text("\(additionalRequests.count)/\(charLimit)")) {
                TextField("예: 최대한 설거지 적게 나오게, 맵지 않게 등", text: $additionalRequests, axis: .vertical)
                    .lineLimit(3...5)
                    .onChange(of: additionalRequests) { oldValue, newValue in
                        // 글자 수가 제한을 넘으면 딱 그만큼만 잘라서 다시 저장
                        if newValue.count > charLimit {
                            additionalRequests = String(newValue.prefix(charLimit))
                        }
                    }
            }
        }
        
        .navigationTitle("레시피 설정")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("다음") {
                    isShowingAlert = true
                }
                .bold() // 완료 버튼은 굵게!
                
            }
        }
        .animation(.default, value: foodName.isEmpty)
        .onAppear{
            requiredFoodIDs = Set(selectedFoods.map{$0.id})
        }
        .alert("레시피를 생성할까요?", isPresented: $isShowingAlert) {
            Button("취소", role: .cancel) {}
            // Alert 안의 "생성" 버튼 액션
            Button("생성") {
                // 💡 프롬프트를 조립하는 대신, 서버로 보낼 데이터만 추출합니다.
                let requiredFoods = selectedFoods.filter { requiredFoodIDs.contains($0.id) }
                let requiredNames = requiredFoods.map { $0.title }.joined(separator: ", ")
                let allNames = selectedFoods.map { $0.title }.joined(separator: ", ")
                
                // 뷰 이동 시 넘겨줄 정보
                currentRecipeOptions = [
                    "allNames": allNames,
                    "requiredNames": requiredNames,
                    "foodName": foodName,
                    "selectedDifficulty": selectedDifficulty,
                    "selectedCuisine": selectedCuisine,
                    "additionalRequests": additionalRequests
                ]
                
                print("설정한 옵션만 서버로 넘겨서 AI 레시피를 만듭니다.")
                
                if storeManager.isPremium {
                    navManager.path.append(.geminiRecipe(options: currentRecipeOptions))
                } else {
                    isShowingStore = true
                }
            }
        }
        .sheet(isPresented: $isShowingStore) {
            MyStoreSheetView(){ // MyStoreSheetView에서 구독하거나, 광고 시청이 OnSucess 함수가 호출되며 navManager.path.append(.geminiRecipe(options: currentRecipeOptions)로 이동
                navManager.path.append(.geminiRecipe(options: currentRecipeOptions))
            }
        }
    }
}

#Preview {
    let navManager = NavigationManager()
    // 1. 프리뷰용 가상 메모리 공간(Container) 만들기
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FoodItem.self, configurations: config)
    
    // 2. 가짜 데이터 생성
    let sampleFoods = [
        FoodItem(title: "앞다리살", expiryDate: Date().addingTimeInterval(86400)),
        FoodItem(title: "양파", expiryDate: Date()),
        FoodItem(title: "다진마늘", expiryDate: Date())
    ]
    
    // 3. 컨테이너에 데이터 밀어넣기
    for food in sampleFoods {
        container.mainContext.insert(food)
    }
    
    // 4. 뷰에 바인딩 연결하고, 컨테이너 환경 주입하기
    return NavigationStack { // 뷰가 잘 보이도록 네비게이션으로 한 번 감싸줍니다
        RecipeOptionView(selectedFoods: .constant(sampleFoods))
    }
    .modelContainer(container) // 👈 가장 핵심!
    .environmentObject(navManager)
}
