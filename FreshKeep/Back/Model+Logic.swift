//
//  Model+Logic.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/7/26.
//

import Foundation

enum FoodExpiryState {
    case expired
    case today
    case urgent
    case fresh
}

extension FoodItem {
    var remainingDays: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiryDay = calendar.startOfDay(for: expiryDate)
        return calendar.dateComponents([.day], from: today, to: expiryDay).day ?? 0
    }
    
    var expiryState: FoodExpiryState {
        if remainingDays < 0 { return .expired }
        if remainingDays == 0 { return .today }
        if remainingDays <= 3 { return .urgent }
        return .fresh
    }
    
    var expiryStatusText: String {
        if remainingDays > 0 { return String(localized: "\(remainingDays)일 남았습니다.") }
        else if remainingDays == 0 { return String(localized: "오늘까지예요.") }
        else { return String(localized: "\(abs(remainingDays))일 지났습니다.") }
    }
}
