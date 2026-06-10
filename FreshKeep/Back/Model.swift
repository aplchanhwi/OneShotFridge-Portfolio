//
//  Model.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/11/26.
//

import Foundation
import SwiftData

// 1. Category (식재료들의 분류)
@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String // 식빵 우유 등
    var defaultShelLife: Int // 지피티 권장 기한 (일 단위)
    var userCustomLife: Int? // 사용자가 저장한 값
    
    // 하나의 카테고리는 여러 개의 Item을 가질 수 있음
    @Relationship(deleteRule: .cascade, inverse: \FoodItem.category)
    var foodItems: [FoodItem]? = []
    
    init(name: String, defaultShelLife: Int, userCustomLife: Int? = nil) {
        self.id = UUID()
        self.name = name
        self.defaultShelLife = defaultShelLife
        self.userCustomLife = userCustomLife
    }
}

// 2. Item (개별 식재료 - 실제 냉장고 품목)
@Model
final class FoodItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var expiryDate: Date
    var registeredAt: Date
    var isConsumed: Bool
    
    // Item은 하나의 카테고리에 속함 (딸기 우유는 우유 카테고리에 속함)
    var category: Category?
    // 이 음식이 나온 출처가 되는 사진
    var sourceSession: CaptureSession?
    
    init(title: String, expiryDate: Date, category: Category? = nil) {
        self.id = UUID()
        self.title = title
        self.expiryDate = expiryDate
        self.registeredAt = Date()
        self.isConsumed = false
        self.category = category
    }
}

// 3. Capturedession (촬영 세션 기록)
@Model
final class CaptureSession {
    @Attribute(.unique) var id: UUID
    var capturedAt: Date
    var originalImage: String // Image Path
    
    @Relationship(deleteRule: .nullify, inverse: \FoodItem.sourceSession)
    var recognizedItems: [FoodItem]? = []
    
    init(originalImage: String) {
        self.id = UUID()
        self.capturedAt = Date()
        self.originalImage = originalImage
    }
}

// 4. Recipe
@Model
final class Recipe {
    @Attribute(.unique) var id: UUID
    var name: String
    var duringTime: Int // 요리 시간
    var items: [String]
    var steps: [String]
    var createdAt: Date

    init(name: String, duringTime: Int, items: [String], steps: [String]) {
        self.id = UUID()
        self.name = name
        self.duringTime = duringTime
        self.items = items
        self.steps = steps
        self.createdAt = Date()
    }
    
}
