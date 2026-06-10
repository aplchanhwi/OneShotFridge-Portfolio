//
//  NavigationManager.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/23/26.
//

import Foundation
import SwiftUI
import Combine

class NavigationManager: ObservableObject {
    @Published var path: [AppDestination] = []
    
    var tempCroppedImages: [AnalyzedItem] = []
    
    // 루트로 돌아가기
    func popToRoot() {
        path.removeAll()
    }
    
    // 뒤로가기 함수
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}
