//
//  FoodEditView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/27/26.
//

import SwiftUI

struct FoodEditView: View {
    @Environment(\.dismiss) var dismiss
    @State var foodItem: FoodItem
    @State var tempName: String = ""
    
    var body: some View {
        NavigationStack{
            VStack{
                if let localImagePath = foodItem.sourceSession?.originalImage {
                    if let uiImage = CaptureManager.shared.loadImageFromDisk(fileName: localImagePath){
                        Image(uiImage: uiImage)
                            .resizable() // 크기 조절 가능하게
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(15)
                            .shadow(radius: 5)
                            .padding()
                    } else {
                        Text("이미지 불러오기 실패1")
                    }
                } else {
                    Text("이미지 불러오기 실패2")
                }
                Form{
                    Section {
                        HStack {
                            Image(systemName: "tag").foregroundColor(.gray)
                            TextField("상품 이름", text: $foodItem.title, prompt: Text("상품 이름을 입력해주세요."))
                                .font(.headline)
                        }
                        HStack{
                            Image(systemName: "calendar").foregroundColor(.gray)
                            DatePicker(
                                "",
                                selection: $foodItem.expiryDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ko_kr"))
                        }
                        
                    }
                }
            }
            .navigationTitle("상품 확인")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        // 여기서 저장 로직을 실행하거나 그냥 닫습니다.
                        dismiss()
                    }
                    .disabled(foodItem.title.isEmpty)
                    .bold() // 완료 버튼은 보통 두껍게 표시해요.
                }
            }
        }
        
        
    }
}

#Preview {
//    FoodEditView()
}
