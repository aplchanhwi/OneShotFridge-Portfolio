//
//  RecipeResponse.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/13/26.
//

import Foundation
struct RecipeResponse: Codable {
    let name: String
    let duringTime: Int
    let items: [String]
    let steps: [String]
}
