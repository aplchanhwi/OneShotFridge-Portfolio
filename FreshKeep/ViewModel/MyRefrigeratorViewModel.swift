//
//  MyRefrigeratorViewModel.swift
//  FreshKeep
//
//  Created by Codex on 6/8/26.
//

import Foundation
import Combine
import SwiftData

/// MyRefrigeratorView의 화면 상태와 저장 액션을 담당하는 ViewModel입니다.
/// 냉장고 화면은 목록을 보여주는 역할에 집중하고, 식재료 추가/수정 시트 열기/소비 처리 같은 행동은 이곳으로 분리합니다.
@MainActor
final class MyRefrigeratorViewModel: ObservableObject {
    /// 수정 시트에 전달할 선택된 식재료입니다.
    /// Optional FoodItem이기 때문에 SwiftUI의 `.sheet(item:)`과 바로 연결할 수 있습니다.
    @Published var selectedFoodItem: FoodItem?
    
    /// 수동 추가 시트 표시 여부입니다.
    /// 냉장고 우측 상단의 + 버튼을 누르면 true가 됩니다.
    @Published var isAddViewShown: Bool = false

    /// 수동 추가 화면을 엽니다.
    /// View에서는 버튼 탭 이벤트만 받고, 실제 상태 변경은 ViewModel이 맡습니다.
    func showAddView() {
        isAddViewShown = true
    }

    /// 목록에서 식재료를 탭했을 때 수정 시트를 열기 위한 상태를 설정합니다.
    func showEditView(for item: FoodItem) {
        selectedFoodItem = item
    }

    /// 식재료를 "먹었다" 상태로 변경합니다.
    /// 현재 모델은 먹음/버림을 구분하지 않고 isConsumed 하나만 사용하므로, 여기서는 true로 바꿉니다.
    /// 상태 변경 후 바로 save해서 앱을 껐다 켜도 결과가 유지되게 합니다.
    func markAsConsumed(_ item: FoodItem, context: ModelContext) {
        item.isConsumed = true
        save(context: context)
    }

    /// FoodAddView에서 전달받은 이름과 소비기한 일수를 실제 FoodItem으로 저장합니다.
    /// FoodAddView는 입력 UI만 담당하고, SwiftData insert는 냉장고 ViewModel에서 처리합니다.
    func addFood(name: String, expiryDays: Int, context: ModelContext) {
        // FoodItem은 Date 형태의 expiryDate를 저장하므로,
        // FoodAddView가 넘겨준 "오늘 기준 일수"를 실제 날짜로 바꿉니다.
        let expiryDate = Calendar.current.date(
            byAdding: .day,
            value: expiryDays,
            to: Date()
        ) ?? Date()

        let foodItem = FoodItem(title: name, expiryDate: expiryDate)
        
        // 같은 이름의 Category가 있으면 재사용하고, 없으면 새로 만듭니다.
        // 이렇게 해야 다음에 같은 식재료를 추가할 때 기존 소비기한 정보를 다시 활용할 수 있습니다.
        foodItem.category = findOrCreateCategory(
            name: name,
            defaultShelfLife: expiryDays,
            context: context
        )

        context.insert(foodItem)
        save(context: context)
    }

    /// 이름이 같은 Category를 찾아 재사용하거나, 없으면 새 Category를 생성합니다.
    /// Category는 식재료별 기본 소비기한과 사용자가 수정한 소비기한을 기억하는 역할을 합니다.
    private func findOrCreateCategory(name: String, defaultShelfLife: Int, context: ModelContext) -> Category {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { category in
                category.name == name
            }
        )

        // 이미 저장된 카테고리가 있다면 새로 만들지 않고 그대로 연결합니다.
        if let category = try? context.fetch(descriptor).first {
            return category
        }

        // 처음 보는 식재료라면 이번에 계산된 소비기한을 기본 기한으로 저장합니다.
        let category = Category(name: name, defaultShelLife: defaultShelfLife)
        context.insert(category)
        return category
    }

    /// SwiftData 변경사항을 저장합니다.
    /// save 호출을 한 곳에 모아두면, 저장 실패 로그 처리도 한 곳에서 관리할 수 있습니다.
    private func save(context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("FoodItem 저장 실패: \(error.localizedDescription)")
        }
    }
}
