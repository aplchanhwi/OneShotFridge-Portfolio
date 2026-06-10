//
//  Model+Logic.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/7/26.
//

import Foundation

extension FoodItem {
    var expiryStatusText: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
        if days > 0 { return String(localized: "\(days)일 남았습니다.") }
        else if days == 0 { return String(localized: "오늘까지 입니다.") }
        else { return String(localized: "\(abs(days))일 지났습니다.") }
    }
}
