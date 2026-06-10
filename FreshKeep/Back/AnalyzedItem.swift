//
//  AnalyzedItem.swift
//  FreshKeep
//
//  Shared image-analysis result model used by the portfolio-safe export.
//

import UIKit

struct AnalyzedItem: Identifiable {
    let id = UUID()
    let croppedImage: UIImage
    var name: String
    var confidence: Float
    var needsGPT: Bool
}
