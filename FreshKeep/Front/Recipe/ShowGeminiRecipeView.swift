//
//  ShowGeminiRecipeView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/13/26.
//

import SwiftUI

struct ShowGeminiRecipeView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @EnvironmentObject var navManager: NavigationManager
    private let geminiService: GeminiService = GeminiService()
    @State private var recipe: RecipeResponse?
    @State private var isLoading: Bool = true
    @State private var isShowingExitDialog: Bool = false
    let options: [String: String]
    
    var previewRecipe: RecipeResponse? = nil // 👈 프리뷰를 위한 가짜 데이터 통로!
    
    var body: some View {
        VStack {
            // 3. 상태에 따라 다른 화면을 보여줍니다.
            if isLoading {
                ProgressView("AI가 열심히 레시피를 고민 중입니다...")
                    .controlSize(.large)
            } else if let recipe = recipe {
                // 레시피가 잘 들어왔을 때
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
                // 나중에 여기서 List나 ForEach로 steps를 예쁘게 그려주면 됩니다!
            } else {
                // 에러가 났거나 nil이 들어왔을 때
                Text("레시피를 불러오는데 실패했어요 😢")
            }
        }
        .navigationTitle(Text("레시피"))
        .navigationBarBackButtonHidden(true)
        .toolbar{
            ToolbarItem(placement: .topBarLeading){
                Button {
                    isShowingExitDialog = true // 이제 다이얼로그가 뜹니다!
                } label: {
                    HStack {
                        Image(systemName: "chevron.left") // 뒤로 가기 화살표
                    }
                }
                .disabled(isLoading)
            }
            
            ToolbarItem(placement: .topBarTrailing){
                Menu {
                    Button(role: .confirm) {
                        saveAndExit()
                    } label: {
                        Label("저장 후 나가기", systemImage: "tray.and.arrow.down.fill")
                    }
                    Button(role: .destructive) {
                        exitWithoutSaving()
                    } label: {
                        Label("나가기", systemImage: "rectangle.portrait.and.arrow.right.fill")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            // 💡 프리뷰 모드일 때: 가짜 데이터가 있으면 API 호출 안 하고 바로 띄워줌!
            if let preview = previewRecipe {
                self.recipe = preview
                self.isLoading = false
                return
            }
            Task {
                let fetchedRecipe = await geminiService.getRecipe(options: options)
                self.recipe = fetchedRecipe
                self.isLoading = false
            }
        }
        .confirmationDialog("레시피를 잃게 됩니다.", isPresented: $isShowingExitDialog, titleVisibility: .visible) {
            Button("재료 다시 선택하러 가기", role: .destructive) { dismiss() }
            Button("취소하기", role: .cancel) {}
        }
    }
    // 뒤로 가기 동작 함수들
    func saveAndExit() {
        guard let recipe else { return print("saveAndExit함수 이상")}
        
        RecipeManager.shared.saveRecipe(recipeResponse: recipe, context: context)
        navManager.popToRoot()
    }
    
    func exitWithoutSaving() {
        navManager.popToRoot()
    }
}
#Preview {
    let navManager = NavigationManager()
    
    let mockJSONString = """
    {
      "name": "봄 내음 가득! 매콤 아삭 봄동비빔밥",
      "duringTime": 15,
      "items": [
        "봄동 150g (약 한 줌)",
        "따뜻한 공깃밥 1공기",
        "고추장 1.5스푼",
        "젤리 1봉지 (식후 디저트용)"
      ],
      "steps": [
        "**1) 봄동 손질하기:**\n봄동은 밑동을 자르고 낱장으로 분리해 흐르는 물에 깨끗이 씻어주세요.\n👉 찬물에 5분 정도 담가두면 아삭한 식감이 극대화됩니다.",
        "**2) 청양고추 다지기:**\n청양고추는 반으로 갈라 씨를 제거한 뒤 아주 잘게 다져주세요.\n🔥 매운맛을 선호하신다면 씨를 포함해도 좋지만, 깔끔한 맛을 위해 제거하는 것을 추천합니다."
      ]
    }
    """
    
    let mockData = mockJSONString.data(using: .utf8)!
    let mockRecipe = try! JSONDecoder().decode(RecipeResponse.self, from: mockData)
    
    return NavigationStack {
        // 💡 프리뷰 호출 시 finalPrompt 대신 가짜 options를 넘겨주도록 수정!
        ShowGeminiRecipeView(
            options: ["dummy": "data"],
            previewRecipe: mockRecipe
        )
    }
    .environmentObject(navManager)
}
