//
//  Item.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/11/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
