//
//  AdManager.swift
//  FreshKeep
//
//  Portfolio-safe mock. Production ad identifiers and Google Mobile Ads
//  integration are intentionally removed from this repository.
//

import Foundation

final class AdManager {
    static let shared = AdManager()

    private init() {}

    func loadAd() {}

    @MainActor
    func showAd() async -> Bool {
        true
    }
}
