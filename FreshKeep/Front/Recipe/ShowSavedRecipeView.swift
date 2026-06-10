//
//  ShowSavedRecipeView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/16/26.
//

import SwiftUI

struct ShowSavedRecipeView: View {
    let recipe: Recipe
    var body: some View {
        List{
            HStack{
                Text(recipe.name)
                    .font(.title)
                    .bold()
                    .listRowBackground(Color.clear) // 제목은 배경 없애기
                Spacer()
                Text("\(recipe.duringTime)분")
                    .font(.title3)
            }
            Section("필요한 재료"){
                ForEach(recipe.items, id: \.self){ item in
                    Text(item)
                }
            }
            Section("조리 순서") {
                ForEach(recipe.steps, id: \.self) { step in
                    Text(LocalizedStringKey(step))
                        .lineSpacing(6)
                }
            }
        }
    }
}

#Preview {
    // 1. DB(ModelContainer) 다 필요 없고, 그냥 가짜 변수 하나만 만듭니다!
    let dummyRecipe = Recipe(
        name: "백종원 뺨치는 김치볶음밥",
        duringTime: 15,
        items: ["신김치 1컵", "밥 1공기", "스팸 100g", "계란 1개", "참기름 1스푼"],
        steps: [
            "**1) 재료 손질:**\n스팸과 김치는 잘게 썰어줍니다.",
            "**2) 파기름 내기:**\n팬에 식용유를 두르고 대파를 볶아 향을 냅니다.",
            "**3) 볶기 🔥:**\n스팸, 김치를 넣고 볶다가 밥을 넣고 불을 끈 상태에서 잘 비벼줍니다.",
            "**4) 마무리 🍳:**\n다시 불을 켜고 참기름을 두른 뒤, 계란 프라이를 올려 완성합니다."
        ]
    )
    
    // 2. 만든 가짜 레시피를 뷰에 쏙 넣어주면 끝!
    return NavigationStack {
        ShowSavedRecipeView(recipe: dummyRecipe)
    }
}
