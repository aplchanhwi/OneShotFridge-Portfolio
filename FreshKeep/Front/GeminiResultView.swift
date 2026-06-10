//
//  TestGeminiView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/23/26.
//

import SwiftUI
import SwiftData

struct GeminiResultView: View {
    
    let mainImage: UIImage
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var navManager: NavigationManager
    
    @StateObject private var viewModel = GeminiResultViewModel()
    
    @State private var foodName: String = ""
    @State private var expiryDate: Int = 0
    
    @State private var editingIndex: Int? = nil
    @State private var isDetailViewShow: Bool = false
    @State private var isAddViewShow: Bool = false
    
    private let geminiService: GeminiService = GeminiService()
    
    var body: some View {
        VStack {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Ai가 식재료와 소비기한을 분석중입니다.")
            case .failed(let message):
                failedView(message: message)
            case .empty(let message):
                emptyView(message: message)
            case .loaded:
                List(Array(viewModel.items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.headline)
                            Text("권장 소비기한: \(item.expiryDays)일")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            guard !item.name.isEmpty else {
                                print("item is empty")
                                return
                            }
                            editingIndex = index
                            foodName = item.name
                            expiryDate = item.expiryDays
                            isDetailViewShow = true
                        }) {
                            Image(systemName: "square.and.pencil")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                VStack {
                    Button(action: {
                        saveToFreshKeep()
                        navManager.popToRoot()
                    }) {
                        Text("내 냉장고에 저장하기")
                    }
                    .buttonStyle(GreenButtonStyle())
                    .padding()
                    .disabled(viewModel.items.isEmpty)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(
            isPresented: $isDetailViewShow,
            content: {
                FoodDetailView(
                    foodName: $foodName,
                    expiryDate: $expiryDate,
                    onSave: { newFoodName, newExpiryDate in
                        if let index = editingIndex {
                            viewModel.updateItem(at: index, name: newFoodName, expiryDays: newExpiryDate)
                            editingIndex = nil
                        }
                    },
                    onDelete: { // 삭제 버튼을 눌렀을 때,
                        if let index = editingIndex {
                            viewModel.deleteItem(at: index)
                            editingIndex = nil // 타겟 초기화
                        }
                    })
                .presentationDetents([.medium])
            }
        )
        .sheet( // 상품 추가 뷰
            isPresented: $isAddViewShow,
            content: {
                // 같은 FoodAddView를 재사용하지만, 여기서는 SwiftData에 바로 저장하지 않습니다.
                // 분석 결과 화면에서는 사용자가 검토 중인 임시 배열(viewModel.items)에만 항목을 추가합니다.
                FoodAddView(title: "분석 결과에 추가") { name, expiryDays in
                    viewModel.addItem(name: name, expiryDays: expiryDays)
                }
                    .presentationDetents([.medium])
                    .interactiveDismissDisabled()
            }
        )
        .navigationTitle("분석 결과")
        .navigationBarTitleDisplayMode(.inline) // 타이틀을 항상 상단 중앙에 고정!
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("추가") {
                    isAddViewShow = true
                }
                .bold()
                .disabled(viewModel.state.isLoading)
            }
        }
//        .onAppear {
//            viewModel.loadMockFailure()
//        }
        
        .onAppear {
            // 💡 Xcode 프리뷰(캔버스)가 실행 중일 때는 아래 로직을 무시함
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                viewModel.loadPreviewData()
                return
            }
            Task { await viewModel.loadAnalysisIfNeeded(image: mainImage, modelContext: modelContext) }
        }
    }
    
    // MARK: - Helper Views & Methods
    
    private func failedView(message: String) -> some View {
        ContentUnavailableView {
            Label("분석 결과를 받아오지 못했습니다.", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button {
                Task {
                    await viewModel.retryAnalysis(image: mainImage, modelContext: modelContext)
                }
            } label: {
                Label("다시 시도", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GreenButtonStyle())
        }
    }
    
    private func emptyView(message: String) -> some View {
        ContentUnavailableView {
            Label("식재료가 모두 비었습니다.", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button {
                Task {
                    await viewModel.retryAnalysis(image: mainImage, modelContext: modelContext)
                }
            } label: {
                Label("다시 시도", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GreenButtonStyle())
        }
    }
    
    private func saveToFreshKeep() {
        CaptureManager.shared.saveCapturedSession(
            originalImage: mainImage,
            gptResults: viewModel.items,
            context: modelContext
        )
    }
}

#Preview {
    let navManager = NavigationManager()
    
    // 💡 NavigationStack으로 감싸야 타이틀 바가 렌더링됩니다!
    return NavigationStack {
        GeminiResultView(mainImage: UIImage(systemName: "sparkles")!)
            .environmentObject(navManager)
    }
}
