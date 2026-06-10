//
//  GeminiResultViewModel.swift
//  FreshKeep
//
//  Created by 강찬휘 on 6/1/26.
//

import Combine
import SwiftData
import SwiftUI

@MainActor
final class GeminiResultViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case failed(message: String)
        case empty(message: String)
        
        var isLoading: Bool {
            if case .loading = self {return true}
            return false
        }
    }
    
    @Published private(set) var state: ViewState = .idle
    @Published private(set) var items: [ResponseItem] = []
    
    private let geminiService: GeminiService
    private var hasRequestedAnalysis: Bool = false
    
    init(geminiService: GeminiService = GeminiService()) {
        self.geminiService = geminiService
    }
    
    func loadAnalysisIfNeeded(image: UIImage, modelContext: ModelContext) async {
        guard !hasRequestedAnalysis else {return}
        await requestAnalysis(image: image, modelContext: modelContext)
    }
    
    func retryAnalysis(image: UIImage, modelContext: ModelContext) async {
        await requestAnalysis(image: image, modelContext: modelContext)
    }
    
    func updateItem(at index: Int, name: String, expiryDays: Int) {
        guard items.indices.contains(index) else {return}
        items[index].name = name
        items[index].expiryDays = expiryDays
        items[index].isEdited = true
    }
    
    func deleteItem(at index: Int) {
        guard items.indices.contains(index) else {return}
        items.remove(at: index)
        if items.isEmpty {
            state = .empty(message: "다시 분석하거나 직접 추가해 주세요.")
        }
    }
    
    func addItem(name: String, expiryDays: Int) {
        guard !name.isEmpty else {return}
        items.append(ResponseItem(name: name, expiryDays: expiryDays, isEdited: true))
        state = .loaded
    }
    
    
    
    func loadMockFailure() {
        items = []
        state = .failed(message: "테스트용 에러입니다.")
        hasRequestedAnalysis = true
    }
    
    
    func loadPreviewData() {
        items = [
            ResponseItem(name: "프리뷰 우유", expiryDays: 5),
            ResponseItem(name: "프리뷰 식빵", expiryDays: 3),
            ResponseItem(name: "프리뷰 달걀", expiryDays: 14)
        ]
        state = .loaded
        hasRequestedAnalysis = true
    }
    
    private func requestAnalysis(image: UIImage, modelContext: ModelContext) async {
        hasRequestedAnalysis = true
        state = .loading
        
        do {
            var analyzedItems = try await geminiService.scanImageResult(image: image)
            applyUserCustomExpiryDays(to: &analyzedItems, modelContext: modelContext)
            items = analyzedItems
            state = .loaded
        } catch {
            items = []
            state = .failed(message: "분석 중 오류가 발생했습니다.")
        }
    }
    
    private func applyUserCustomExpiryDays(to analyzedItems: inout [ResponseItem], modelContext: ModelContext) {
        for index in analyzedItems.indices {
            let name = analyzedItems[index].name
            let descriptor = FetchDescriptor<Category>(
                predicate: #Predicate<Category> { $0.name == name}
            )
            
            if let existingCategory = try? modelContext.fetch(descriptor).first,
               let customLife = existingCategory.userCustomLife {
                analyzedItems[index].expiryDays = customLife
            }
        }
    }
}
