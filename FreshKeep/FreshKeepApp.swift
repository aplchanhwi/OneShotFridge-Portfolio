//
//  FreshKeepApp.swift
//  FreshKeep
//
//  Portfolio-safe app entry point. Production Firebase, ads, tracking,
//  and push-notification setup are intentionally removed.
//

import SwiftUI
import SwiftData

@main
struct FreshKeepApp: App {
    @StateObject private var storeManger = StoreManager.shared

    init() {
        let _ = AdManager.shared

        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)

        if let appSupportURL = urls.first,
           !fileManager.fileExists(atPath: appSupportURL.path) {
            do {
                try fileManager.createDirectory(
                    at: appSupportURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print("Application Support directory creation failed: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            GetImageView()
                .environmentObject(storeManger)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [CaptureSession.self, Category.self, FoodItem.self, Recipe.self])
    }
}
