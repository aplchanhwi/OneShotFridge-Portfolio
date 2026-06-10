//
//  OpenAIService.swift
//  FreshKeep
//
//  Portfolio-safe mock. Production API keys and direct network calls are
//  intentionally removed from this repository.
//

import Foundation
import UIKit

final class OpenAIService {
    static let shared = OpenAIService()

    private init() {}

    func analyzeCrops(images: [UIImage], completion: @escaping @Sendable ([ResponseItem]?) -> Void) {
        let sampleItems = [
            ResponseItem(name: "Tomato", expiryDays: 5),
            ResponseItem(name: "Milk", expiryDays: 7)
        ]
        completion(sampleItems)
    }
}

struct rootResponse: Codable, Sendable {
    let items: [ResponseItem]
}

struct ResponseItem: Codable, Sendable {
    var name: String
    var expiryDays: Int
    var isEdited: Bool = false

    enum CodingKeys: String, CodingKey {
        case name
        case expiryDays
    }
}
