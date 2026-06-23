//
//  StoreManager.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/2/26.
//

import Foundation
import Combine
import StoreKit
import SwiftUI

@MainActor
class StoreManager: ObservableObject {
    @Published var isPremium: Bool = false
    private var updates: Task<Void, Never>? = nil
    static let shared = StoreManager()

    private init() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            return
        }
        
        // 앱 켜지자마자 결제 업데이트 감시 시작!
        updates = Task {
            for await _ in Transaction.updates {
                await self.updateStatus()
            }
        }
        
        Task{
            await updateStatus()
        }
    }

    func updateStatus() async {
        for await result in Transaction.currentEntitlements { // 결제가 완료되면 
            if case .verified(_) = result {
                self.isPremium = true
                return
            }
        }
        self.isPremium = false
    }
}
