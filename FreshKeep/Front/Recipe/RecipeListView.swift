//
//  RecipeListView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/15/26.
//

import SwiftUI
import _SwiftData_SwiftUI

struct RecipeListView: View {
    @Query() var recipes: [Recipe]
    @EnvironmentObject var navManger: NavigationManager
    @Environment(\.modelContext) var context
    
    @State private var isShowingRenameAlert: Bool = false
    @State private var recipeToRename: Recipe? = nil
    @State private var newRecipeName: String = ""
    
    @State private var selectedSort: RecipeSortOption = .latest
    private var sortedRecipes: [Recipe] {
        switch selectedSort {
        case .name:
            return recipes.sorted{$0.name < $1.name}
        case .step:
            return recipes.sorted{$0.steps.count < $1.steps.count}
        case .time:
            return recipes.sorted{$0.duringTime < $1.duringTime}
        case .latest:
            return recipes.sorted{$0.createdAt > $1.createdAt}
        }
    }
    var body: some View {
        VStack{
            if sortedRecipes.isEmpty{
                VStack(spacing: 20) {
                    Image(systemName: "menucard")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("레시피가 없어요!")
                        .font(.title2.bold())
                    Text("새로운 레시피를 추가해 보세요.")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            else{
                List {
                    ForEach(sortedRecipes){ recipe in
                        HStack{
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(recipe.name)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    Text("\(recipe.duringTime)분 / \(recipe.steps.count)단계")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Menu(content: {
                                    Button("레시피 이름 변경") {
                                        recipeToRename = recipe
                                        isShowingRenameAlert = true
                                    }
                                    Button(role: .destructive, action: {
                                        RecipeManager.shared.deleteRecipe(recipe: recipe, context: context)
                                    }){Text("레시피 삭제")}
                                }){
                                    Label("", systemImage: "ellipsis")
                                }
                            }
                            .contentShape(Rectangle()) // 버튼 영역 최적화
                            .onTapGesture {
                                navManger.path.append(.savedRecipe(recipe: recipe))
                            }
                            .foregroundColor(.white) // 버튼 강조색
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation{ RecipeManager.shared.deleteRecipe(recipe: recipe, context: context) }
                                } label : {
                                    Image(systemName: "trash.fill")
                                        .tint(.red)
                                }
                            }
                        }
                    }
                    
                }
                
            }
        }
        .alert("레시피 이름 변경", isPresented: $isShowingRenameAlert) {
            TextField("새로운 이름을 입력하세요", text: $newRecipeName)
            Button(role: .cancel)
            {
                recipeToRename = nil
                newRecipeName = ""
            }
            Button(role: .confirm){
                if let recipe = recipeToRename, !newRecipeName.isEmpty {
                    recipe.name = newRecipeName
                    try? context.save()
                }
                newRecipeName = ""
                recipeToRename = nil
            }
        }
        
        .navigationTitle(Text("레시피 리스트"))
        .toolbar{
            ToolbarItem(placement: .topBarTrailing) {	
                Menu("", systemImage: "line.3.horizontal.decrease") {
                    Button(action: { selectedSort = .latest }){
                        Label("최근 추가된 순", systemImage: selectedSort == .latest ? "checkmark" : "")
                    }
                    Button(action: { selectedSort = .name }){
                        Label("이름순", systemImage: selectedSort == .name ? "checkmark" : "")
                    }
                    Button(action: { selectedSort = .step }){
                        Label("간단한 순", systemImage: selectedSort == .step ? "checkmark" : "")
                    }
                    Button(action: { selectedSort = .time }){
                        Label("빠른 조리순", systemImage: selectedSort == .time ? "checkmark" : "")
                    }
                    
                }
                
            }
        }
    }
}

enum RecipeSortOption {
    case name // 가나다 순서
    case step // 조리 수 순서
    case time // 조리 시간 순서
    case latest // 최신 순서
}

#Preview {
    // 1. 실제 기기 저장소 대신 메모리(램)에만 저장되는 '가짜 냉장고(컨테이너)' 생성
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Recipe.self, configurations: config)
    
    // 2. 가짜 데이터(가라) 만들기
    let recipe1 = Recipe(
        name: "참치 알리오올리오",
        duringTime: 15,
        items: ["파스타면 100g", "참치 1캔", "통마늘 5알", "올리브오일 3스푼", "페퍼론치노 3개"],
        steps: [
            "1) 마늘은 편 썰고, 참치는 기름을 빼서 준비합니다.",
            "2) 약불에 올리브오일을 두르고 마늘과 페퍼론치노를 볶아 향을 냅니다.",
            "3) 삶은 파스타면과 참치를 넣고 면수와 함께 빠르게 볶아 완성합니다."
        ]
    )
    
    let recipe2 = Recipe(
        name: "매콤달콤 봄동 떡볶이",
        duringTime: 20,
        items: ["밀떡 200g", "어묵 2장", "봄동 반 줌", "고추장 2스푼", "설탕 1.5스푼"],
        steps: [
            "1) 떡은 물에 불려두고 어묵과 봄동은 먹기 좋게 썹니다.",
            "2) 끓는 물에 고추장과 설탕을 풀고 떡을 먼저 넣어 익힙니다.",
            "3) 떡이 떠오르면 어묵을 넣고 졸이다가 마지막에 봄동을 넣어 숨만 죽여 완성합니다."
        ]
    )
    let recipe3 = Recipe(
        name: "초간단 5분 간장계란밥",
        duringTime: 5, // 👈 가장 짧은 시간 테스트용!
        items: ["따뜻한 밥 1공기", "계란 1개", "간장 1스푼", "참기름 1스푼", "깨 약간"],
        steps: [
            "1) 팬에 기름을 넉넉히 두르고 계란 프라이를 반숙으로 튀기듯 굽습니다.",
            "2) 밥 위에 계란을 올리고 간장과 참기름을 뿌려 슥슥 비벼 먹습니다."
        ] // 👈 스텝도 단 2개! (스텝 짧은순 1등 후보)
    )
    
    let recipe4 = Recipe(
        name: "손님맞이용 밀푀유 나베",
        duringTime: 45, // 👈 가장 긴 시간 테스트용!
        items: ["알배기 배추 1통", "깻잎 1묶음", "샤브샤브용 소고기 300g", "숙주 2줌", "멸치 다시마 육수 1L"],
        steps: [
            "1) 배추, 깻잎, 소고기 순서로 차곡차곡 층을 쌓아줍니다.",
            "2) 냄비 높이에 맞춰 3~4등분으로 썰어줍니다.",
            "3) 냄비 바닥에 숙주를 듬뿍 깔고 썰어둔 재료를 가장자리부터 둥글게 채워 넣습니다.",
            "4) 미리 끓여둔 진한 육수를 붓고 중불에서 끓입니다.",
            "5) 고기가 완전히 익으면 칠리소스나 폰즈소스에 푹 찍어 먹습니다."
        ] // 👈 스텝 5개! (스텝 긴 요리)
    )
    
    let recipe5 = Recipe(
        name: "포슬포슬 전자레인지 계란찜",
        duringTime: 10,
        items: ["계란 3개", "물 100ml", "소금 1/2티스푼", "송송 썬 대파 약간", "참기름 약간"],
        steps: [
            "1) 전자레인지용 깊은 용기에 계란을 깨고 알끈을 제거하며 잘 풀어줍니다.",
            "2) 물과 소금을 넣고 거품이 나지 않게 살살 한 번 더 섞어줍니다.",
            "3) 대파를 올리고 랩을 씌운 뒤, 포크로 구멍을 3개 정도 뚫어줍니다.",
            "4) 전자레인지에 3~4분 돌려준 뒤, 꺼내서 참기름을 살짝 뿌려 완성합니다."
        ]
    )
    
    // 💡 잊지 말고 가짜 냉장고에 추가로 쑤셔 넣어주세요!
    container.mainContext.insert(recipe3)
    container.mainContext.insert(recipe4)
    container.mainContext.insert(recipe5)
    // 3. 가짜 냉장고에 재료 쑤셔 넣기!
    container.mainContext.insert(recipe1)
    container.mainContext.insert(recipe2)
    
    // 4. 툴바를 보려면 NavigationStack이 필수입니다.
    return NavigationStack {
        RecipeListView()
    }
    .modelContainer(container) // 💡 이 뷰는 방금 만든 가짜 냉장고를 쓴다고 알려줌
}
