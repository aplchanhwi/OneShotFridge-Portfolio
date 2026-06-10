//
//  NotificationManager.swift
//  FreshKeep
//
//  Created by 강찬휘 on 5/13/26.
//

import UserNotifications
import Foundation
import _SwiftData_SwiftUI

// "소비기한 임박! 돼지 목심 외 3건의 기한이 얼마 남지 않았어요."
struct NotificationManager {
    static let shared = NotificationManager()
    
    func scheduleFoodNotification(itemName: String, expiryDate: Date, allItems: [FoodItem]) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 원샷 냉장고 알림 🚨"
        content.sound = .default
        
        // 같은 날짜에 만료되는 식품들 필터링
        let calender = Calendar.current
        let sameDayItems = allItems.filter{ calender.isDate($0.expiryDate, inSameDayAs: expiryDate)}
        
        // 문구 생성
        if sameDayItems.count <= 1 {
            content.body = "'\(itemName)'의 기한이 얼마 남지 않았어요."
        } else {
            content.body = "'\(itemName)' 외 \(sameDayItems.count - 1)건의 기한이 얼마 남지 않았어요."
        }
        
        // 날짜 기반 ID 생성
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateId = formatter.string(from: expiryDate)
        
        // 알림 시간 설정 (09시로 설정)
        var dateComponets = calender.dateComponents([.year, .month, .day], from: expiryDate)
        dateComponets.hour = 9
        dateComponets.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponets, repeats: false)
        
        // 알림 요청 (dateId가 같으면, 자동으로 기존 예약을 업데이트함)
        let request = UNNotificationRequest(identifier: dateId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 알림 업데이트 실패: \(error)")
            } else {
                print("✅ [\(dateId)] 요약 알림 업데이트 완료: \(content.body)")
            }
        }
    }
    
    func updateFoodNotifications(allFoodList: [FoodItem]) {
        // 1. 일단 기존에 예약된 미래의 알림들을 싹 지웁니다. (새로 고침을 위해)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("1. updateFoodNotifications")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 2. 소비되지 않은 식품 중, 유통기한이 오늘 이후인 것들만 날짜별로 묶습니다.
        // Dictionary(grouping:)을 쓰면 날짜별로 식품 리스트가 묶입니다.
        let groupedFoods = Dictionary(grouping: allFoodList.filter { !$0.isConsumed && $0.expiryDate >= today }) { food in
            calendar.startOfDay(for: food.expiryDate) // <- 연월일까지 살리고 시분초등은 다 버림 ex) 2026-05-15 00:00:00 
        }
        print("2. updateFoodNotifications")
        // 3. 각 날짜별로 알림을 하나씩 예약합니다.
        for (date, foods) in groupedFoods {
            print("[\(date), \(foods)]")
            
            let content = UNMutableNotificationContent()
            content.title = "🚨 소비기한 임박 🚨"
            content.sound = .default
            
            let count = foods.count
            let firstFoodName = foods.first?.title ?? "식품"
            
            // 알림 문구
            if count == 1 { // 임박 식품이 하나일 경우
                content.body = "'\(firstFoodName)'의 기한이 오늘까지예요!"
            } else { // 두개 이상일 경우
                content.body = "'\(firstFoodName)' 외 \(count - 1)건의 기한이 오늘까지예요!"
            }
            
            // 4. 해당 날짜의 오전 9시로 트리거 설정
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            dateComponents.hour = 9
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // 날짜를 ID로 써서 중복 예약을 방지합니다. (예: "2026-05-14")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let identifier = formatter.string(from: date)
            
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // 5. 알림 예약 (Schedule)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ [\(identifier)] 예약 실패: \(error)")
                } else {
                    print("📅 [\(identifier)] 알림 예약 완료: \(content.body)")
                }
            }
        }
    }
}
