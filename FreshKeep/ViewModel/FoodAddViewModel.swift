//
//  FoodAddViewModel.swift
//  FreshKeep
//
//  Created by Codex on 6/8/26.
//

import Foundation
import Combine

/// FoodAddView의 입력 상태와 소비기한 결정 로직을 담당하는 ViewModel입니다.
/// View가 직접 날짜 계산, 기존 카테고리 조회 결과 판단, Gemini 호출 상태를 모두 알면 화면 코드가 길어지기 때문에 분리했습니다.
@MainActor
final class FoodAddViewModel: ObservableObject {
    /// 사용자가 입력한 식재료 이름입니다.
    @Published var foodName: String = ""
    
    /// 사용자가 직접 선택한 소비기한 날짜입니다.
    /// 날짜를 선택하지 않은 경우 nil로 유지하고, 기존 Category 또는 Gemini 조회를 사용합니다.
    @Published var selectedDate: Date?
    
    /// DatePicker를 화면에 보여줄지 결정합니다.
    /// 처음부터 DatePicker를 보여주면 화면이 무거워 보여서, 사용자가 날짜 입력을 선택한 뒤에만 true로 바꿉니다.
    @Published var isDatePickerShown: Bool = false
    
    /// GeminiService로 소비기한을 조회하는 동안 true가 됩니다.
    /// 이 값을 View가 관찰해서 ProgressView를 보여줍니다.
    @Published var isLoading: Bool = false

    /// 새 식재료의 기본 소비기한을 서버에 물어볼 때 사용합니다.
    /// init으로 주입받게 만들어서 나중에 테스트용 Mock 서비스로 바꾸기 쉽게 했습니다.
    private let geminiService: GeminiService

    /// 완료 버튼 비활성화 조건입니다.
    /// 공백만 입력한 경우도 빈 입력으로 보고, 로딩 중에는 중복 요청을 막습니다.
    var isSaveDisabled: Bool {
        foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
    }

    init(geminiService: GeminiService = GeminiService()) {
        self.geminiService = geminiService
    }

    /// 사용자가 "날짜 직접 입력"을 누르면 DatePicker가 나타나도록 상태를 바꿉니다.
    /// selectedDate가 nil이면 DatePicker가 표시할 기본값이 필요하므로 오늘 날짜를 넣어둡니다.
    func showDatePicker() {
        if selectedDate == nil {
            selectedDate = Date()
        }
        isDatePickerShown = true
    }

    /// FoodAddView에서 입력한 값을 부모 화면이 저장할 수 있는 형태로 정리합니다.
    ///
    /// 소비기한을 정하는 우선순위:
    /// 1. 사용자가 날짜를 직접 선택했다면, 오늘부터 선택 날짜까지의 일수를 계산합니다.
    /// 2. 같은 이름의 Category가 이미 있다면, 사용자가 수정한 기한 또는 기본 기한을 재사용합니다.
    /// 3. 둘 다 없다면 GeminiService에 식재료 이름을 보내 권장 소비기한을 받아옵니다.
    ///
    /// 반환값의 expiryDays는 실제 Date가 아니라 "오늘 기준 며칠 뒤"입니다.
    /// 이렇게 하면 AI 결과 화면과 냉장고 직접 추가 화면이 같은 데이터를 받아 각자 필요한 방식으로 저장할 수 있습니다.
    func makeSaveData(categories: [Category]) async -> (name: String, expiryDays: Int)? {
        let trimmedName = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        // 사용자가 직접 날짜를 골랐다면 AI나 기존 Category보다 사용자의 선택을 우선합니다.
        if let selectedDate {
            return (trimmedName, daysUntil(selectedDate))
        }

        // 이미 한 번 저장된 식재료라면 그때의 소비기한 정보를 재사용합니다.
        // 사용자가 수정한 기한(userCustomLife)이 있으면 기본값보다 우선합니다.
        if let category = categories.first(where: { $0.name == trimmedName }) {
            return (trimmedName, category.userCustomLife ?? category.defaultShelLife)
        }

        // 처음 보는 식재료이고 날짜도 직접 입력하지 않았다면 Gemini에게 권장 소비기한을 물어봅니다.
        // isLoading을 true로 바꿔 View가 로딩 UI를 보여주게 합니다.
        isLoading = true
        let expiryDays = await geminiService.getEXP(foodName: trimmedName)
        isLoading = false
        return (trimmedName, expiryDays)
    }

    /// 선택한 날짜가 오늘로부터 며칠 뒤인지 계산합니다.
    /// startOfDay를 사용해서 현재 시각 때문에 하루 차이가 흔들리는 일을 줄입니다.
    private func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}
