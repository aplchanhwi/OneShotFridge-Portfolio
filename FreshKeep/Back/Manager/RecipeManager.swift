//
//  RecipeManager.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/15/26.
//

import Foundation
import SwiftData

@MainActor
class RecipeManager {
    static let shared = RecipeManager()
    private init() {}
    
    // gemini로 온 RecipeResponese를 받아서 Swift 내 Model로 저장
    func saveRecipe(recipeResponse: RecipeResponse, context: ModelContext) {
        let recipe = Recipe(
            name: recipeResponse.name,
            duringTime: recipeResponse.duringTime,
            items: recipeResponse.items,
            steps: recipeResponse.steps
        )
        
        context.insert(recipe) // 저장 장바구니에 넣기
        
        do {
            try context.save() // 저장 결제
            print("recipe save complete")
        } catch {
            print("Error saving recipe: \(error)")
        }
    }
    
    func deleteRecipe(recipe: Recipe, context: ModelContext) {
        context.delete(recipe)
        do {
            try context.save()
            print("recipe delete complete")
        } catch {
            print("Error deleting recipe: \(error)")
        }
    }
}
