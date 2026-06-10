//
//  DestinationManager.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/7/26.
//

import Foundation
import UIKit

enum AppDestination: Hashable {
    case showImage(mainImage: UIImage, id: UUID = UUID())         // 1: ShowImageView
    case gptResult              // GPTResultView (Legacy)
    case geminiResult           // GeminiResultView
    case refrigerator           // MyRefrigeratorView
    case store                  // MyStoreView
    case smartRecipe            // 스마트 레시피
    case recipeOption(selectedFoods: RecipeSelection)           // 레시피 옵션
    case geminiRecipe(options: [String: String])           // geminiRecipeView
    case recipeList
    case savedRecipe(recipe: Recipe)
    case storeFull
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .showImage(_, let id): hasher.combine(id)
        case .recipeOption(let selectedFoods): hasher.combine(selectedFoods)
        case .savedRecipe(let recipe): hasher.combine(recipe)
        default: hasher.combine(String(describing: self))
        }
    }
    
    static func == (lhs: AppDestination, rhs: AppDestination) -> Bool {
        switch (lhs, rhs) {
        case (.showImage(_, let id1), .showImage(_, let id2)):
            return id1 == id2
        case (.gptResult, .gptResult): return true
        case (.geminiResult, .geminiResult): return true
        case (.refrigerator, .refrigerator): return true
        case (.store, .store): return true
        case (.storeFull, .storeFull): return true
        case (.smartRecipe, .smartRecipe): return true
        case (.geminiRecipe, .geminiRecipe): return true
        case (.recipeOption(let sel1), .recipeOption(let sel2)):
            return sel1 == sel2 // RecipeSelection 구조체끼리 비교
        default:
            return false // 케이스가 서로 다르면 무조건 false
        }
    }
}
struct RecipeSelection: Hashable {
    let foods: [FoodItem]
}
