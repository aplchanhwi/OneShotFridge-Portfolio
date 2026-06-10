//
//  SelectFoodsView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/7/26.
//

import SwiftUI
import SwiftData

struct SelectFoodsView: View {
    @Query(
        filter: #Predicate<FoodItem> { $0.isConsumed == false },
        sort: \FoodItem.expiryDate,
        order:.forward
    ) var allFoods: [FoodItem]
    @EnvironmentObject var navManger: NavigationManager
    let columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
    
    @State var selectedFoods: [FoodItem] = []
    @State var isAskConsumedSheetShown: Bool = false
    
    var body: some View {
        ScrollView{
            LazyVGrid(columns: columns) {
                ForEach(allFoods) { food in
                    let isContained = selectedFoods.contains(where: { $0.id == food.id })
                    
                    VStack{
                        Text(food.title)
                            .font(.title2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(food.expiryStatusText)
                            .font(.caption)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isContained {
                            selectedFoods.removeAll(where: { $0.id == food.id })
                        } else {
                            selectedFoods.append(food)
                        }
                    }
                    .background(isContained ? Color.blue : Color.gray.opacity(0.2))
                    .cornerRadius(10)
                }
            }
        }
        .navigationTitle("식재료 고르기")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("다음") {
                    let selection = RecipeSelection(foods: selectedFoods)
                    navManger.path.append(.recipeOption(selectedFoods: selection))
                }
                .bold() // 완료 버튼은 굵게!
                .disabled(selectedFoods.isEmpty)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FoodItem.self, configurations: config)
    
    let sampleFoods = [
        FoodItem(title: "사과", expiryDate: Date().addingTimeInterval(86400 * 3)),
        FoodItem(title: "우유", expiryDate: Date().addingTimeInterval(86400 * 1)),
        FoodItem(title: "계란", expiryDate: Date().addingTimeInterval(86400 * 5)),
        FoodItem(title: "닭가슴살", expiryDate: Date().addingTimeInterval(-86400 * 1)),
        FoodItem(title: "삼겹살", expiryDate: Date().addingTimeInterval(86400 * 7)),
        FoodItem(title: "상추", expiryDate: Date().addingTimeInterval(86400 * 2)),
        FoodItem(title: "요거트", expiryDate: Date().addingTimeInterval(86400 * 4))
    ]
    
    for food in sampleFoods {
        container.mainContext.insert(food)
    }
    
    return SelectFoodsView()
        .modelContainer(container)
}
