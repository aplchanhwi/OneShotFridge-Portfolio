//
//  FoodAddView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/20/26.
//

import SwiftUI
import SwiftData

/// 식재료 이름과 소비기한을 입력받는 공용 추가 화면입니다.
/// - AI 분석 결과 화면에서는 "분석 결과 배열에 항목 추가" 용도로 사용합니다.
/// - 냉장고 화면에서는 "SwiftData에 실제 FoodItem 저장" 용도로 사용합니다.
/// 저장 방식은 화면마다 다르기 때문에, 이 View는 직접 저장하지 않고 onSave 클로저로 결과만 전달합니다.
struct FoodAddView: View {
    /// 화면 상단에 표시할 제목입니다. 호출하는 화면의 목적에 맞게 문구만 바꿔 재사용합니다.
    let title: String
    
    /// 입력이 완료되었을 때 부모 View로 넘길 저장 이벤트입니다.
    /// FoodAddView는 저장 책임을 갖지 않고, 이름과 "오늘부터 며칠 뒤인지"만 전달합니다.
    let onSave: (String, Int) -> Void
    
    @Environment(\.dismiss) var dismiss // 시트를 닫기 위한 변수
    
    /// 이미 저장된 Category 목록입니다.
    /// 사용자가 날짜를 직접 선택하지 않은 경우, 같은 식재료의 기존 소비기한 값을 재사용하기 위해 조회합니다.
    @Query private var allCategoryList: [Category]

    /// 입력 상태와 소비기한 계산 로직은 ViewModel에서 관리합니다.
    /// View는 화면을 그리는 역할에 집중하고, 판단 로직은 ViewModel로 분리합니다.
    @StateObject private var viewModel: FoodAddViewModel

    init(
        title: String = "상품 추가",
        geminiService: GeminiService = GeminiService(),
        onSave: @escaping (String, Int) -> Void
    ) {
        self.title = title
        self.onSave = onSave
        
        /// StateObject는 init에서 직접 대입할 수 없어서, 언더스코어 저장소에 초기값을 넣습니다.
        /// 이렇게 하면 FoodAddView가 다시 그려져도 같은 ViewModel 인스턴스가 유지됩니다.
        _viewModel = StateObject(wrappedValue: FoodAddViewModel(geminiService: geminiService))
    }
    
    var body: some View {
        NavigationView {
            // 날짜를 직접 고르지 않았고 기존 Category도 없으면 Gemini로 소비기한을 조회합니다.
            // 그동안 사용자가 중복 저장하지 않도록 로딩 화면을 보여줍니다.
            if viewModel.isLoading {
                ProgressView("Ai가 상품의 소비기한을 분석 중입니다. \n잠시만 기다려 주세요.")
            } else {
                Form {
                    Section(header: Text("식재료 정보")) {
                        // 상품명 입력
                        HStack {
                            Image(systemName: "tag").foregroundColor(.gray)
                            TextField("상품 이름", text: $viewModel.foodName, prompt: Text("*상품 이름을 입력해주세요."))
                        }
                        
                        // 소비기한 입력 (숫자)
                        HStack {
                            Image(systemName: "calendar").foregroundColor(.gray)
                            
                            // 사용자가 직접 날짜를 입력하기로 선택한 뒤에만 DatePicker를 보여줍니다.
                            // 기본 상태에서는 입력 화면을 가볍게 유지하기 위해 안내 문구만 표시합니다.
                            if viewModel.isDatePickerShown {
                                HStack{
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            // selectedDate는 Optional이지만 DatePicker는 non-optional Date가 필요합니다.
                                            // nil이면 오늘 날짜를 임시 기본값으로 보여주고, 변경 시 ViewModel에 저장합니다.
                                            get: { viewModel.selectedDate ?? Date() },
                                            set: { viewModel.selectedDate = $0 }
                                        ),
                                        displayedComponents: .date
                                    )
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "ko_kr"))
                                    Spacer()
                                    Text("까지")
                                }
                            } else {
                                Text("터치해서 날짜를 직접 입력하기.")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .onTapGesture {
                                        viewModel.showDatePicker()
                                    }
                            }
                        }
                    }
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline) // 중앙 정렬된 깔끔한 제목
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("취소") { dismiss() } // 시트 닫기
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("완료") {
                            Task {
                                // 입력값을 최종 저장 가능한 형태로 변환합니다.
                                // 날짜 직접 선택 -> 날짜 차이를 일수로 계산
                                // 기존 Category 있음 -> 저장된 기본/사용자 지정 소비기한 사용
                                // 둘 다 없음 -> GeminiService로 소비기한 조회
                                guard let saveData = await viewModel.makeSaveData(categories: allCategoryList) else {
                                    return
                                }
                                
                                // 실제 저장은 부모 화면이 담당합니다.
                                // 같은 FoodAddView를 여러 화면에서 재사용하기 위한 핵심 지점입니다.
                                onSave(saveData.name, saveData.expiryDays)
                                dismiss()
                            }
                        }
                        .bold() // 완료 버튼은 굵게!
                        .disabled(viewModel.isSaveDisabled)
                    }
                }
            }

        }

    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Category.self, FoodItem.self, CaptureSession.self, Recipe.self,
        configurations: config
    )
    
    return FoodAddView { _, _ in }
        .modelContainer(container)
}
