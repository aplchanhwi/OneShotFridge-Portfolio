//
//  FoodDetailView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/20/26.
//

import SwiftUI

struct FoodDetailView: View {
    @Binding var foodName: String
    @Binding var expiryDate: Int
    
    @State private var tempFoodName: String = ""
    @State private var tempExpiryDate: Int = 0
    
    @Environment(\.dismiss) var dismiss // 시트를 닫기 위한 변수
    
    var onSave: (String, Int) -> Void
    var onDelete: () -> Void
    
    var body: some View {
        // 1️⃣ NavigationView로 감싸서 타이틀과 버튼 영역을 만듭니다.
        NavigationView {
            // 2️⃣ VStack 대신 Form을 사용합니다. (자동으로 세련된 입력 그룹이 됨)
            Form {
                Section(header: Text("식재료 정보 수정")) { // 3️⃣ 섹션으로 나누기
                    // 상품명 입력 필드
                    HStack {
                        Image(systemName: "tag").foregroundColor(.gray)
                        TextField("상품 이름", text: $tempFoodName, prompt: Text("*상품 이름을 입력해주세요."))
                    }
                    
                    // 소비기한 입력 필드 (숫자)
                    HStack {
                        Image(systemName: "calendar").foregroundColor(.gray)
                        TextField("소비기한", value: $tempExpiryDate, format: .number, prompt: Text("소비기한을 입력해주세요. (선택)"))
                            .keyboardType(.numberPad)
                        Text("일").foregroundColor(.gray) // 단위 표시
                    }
                }
            }
            // 4️⃣ 시트 제목 설정
            .navigationTitle("상품 수정")
            .navigationBarTitleDisplayMode(.inline) // 중앙 정렬된 깔끔한 제목
            // 5️⃣ 상단 버튼 추가
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(
                        role: .destructive,
                        action: {
                            onDelete()
                            dismiss()
                        }){Text("삭제")}
                        .tint(Color.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
//                        foodName = tempFoodName
//                        expiryDate = tempExpiryDate
                        onSave(tempFoodName, tempExpiryDate)
                        dismiss() // 시트 닫기
                    }
                    .bold() // 완료 버튼은 굵게!
                }
            }
        }
        .onAppear {
            tempFoodName = foodName
            tempExpiryDate = expiryDate
        }
    }
}

#Preview {
    let navManager = NavigationManager()
    
    // 💡 NavigationStack으로 감싸야 타이틀 바가 렌더링됩니다!
    return NavigationStack {
        GeminiResultView(mainImage: UIImage(systemName: "sparkles")!)
            .environmentObject(navManager)
    }
}
