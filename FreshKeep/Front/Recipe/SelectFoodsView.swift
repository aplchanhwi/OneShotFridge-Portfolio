//
//  SelectFoodsView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/7/26.
//

import SwiftUI
import SwiftData

private enum SelectFoodsFilter: CaseIterable, Identifiable {
    case all
    case expired
    case needsAttention
    case today
    case fresh
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .all:
            return String(localized: "전체")
        case .expired:
            return String(localized: "기한 지남")
        case .needsAttention:
            return String(localized: "임박")
        case .today:
            return String(localized: "오늘")
        case .fresh:
            return String(localized: "여유")
        }
    }
    
    func matches(_ item: FoodItem) -> Bool {
        switch self {
        case .all:
            return true
        case .expired:
            return item.expiryState == .expired
        case .needsAttention:
            return item.remainingDays > 0 && item.remainingDays <= 3
        case .today:
            return item.expiryState == .today
        case .fresh:
            return item.expiryState == .fresh
        }
    }
}

struct SelectFoodsView: View {
    @Query(
        filter: #Predicate<FoodItem> { $0.isConsumed == false },
        sort: \FoodItem.expiryDate,
        order:.forward
    )
    private var allFoods: [FoodItem]
    
    @EnvironmentObject private var navManger: NavigationManager
    
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    @State private var selectedFoods: [FoodItem] = []
    @State private var selectedFilter: SelectFoodsFilter = .all
    
    private var filteredFoods: [FoodItem] {
        allFoods.filter { selectedFilter.matches($0) }
    }
    
    var body: some View {
        Group {
            if allFoods.isEmpty {
                emptyFoodsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
//                        dashboardView
                        filterChipsView
                        
                        if filteredFoods.isEmpty {
                            filteredEmptyView
                        } else {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(filteredFoods) { food in
                                    foodSelectionCard(for: food)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .navigationTitle("식재료 고르기")
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("다음", action: goToRecipeOption)
                    .bold()
                .disabled(selectedFoods.isEmpty)
            }
        }
    }
    
    private var emptyFoodsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "refrigerator")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("고를 수 있는 식재료가 없어요.")
                .font(.title3.bold())
            Text("냉장고에 식재료를 먼저 추가해 주세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var dashboardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("먼저 쓰면 좋은 식재료 \(attentionCount)개")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("기한이 가까운 재료를 중심으로 레시피 후보를 만들 수 있어요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 10) {
                summaryCard(
                    title: String(localized: "기한 지남"),
                    count: count(for: .expired),
                    tint: .red
                )
                summaryCard(
                    title: String(localized: "오늘까지"),
                    count: count(for: .today),
                    tint: .orange
                )
                summaryCard(
                    title: String(localized: "선택됨"),
                    count: selectedFoods.count,
                    tint: .blue
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SelectFoodsFilter.allCases) { filter in
                    filterChip(for: filter)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }
    
    private var filteredEmptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("이 조건에 맞는 식재료가 없어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedFoods.count)개 선택됨")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                
                Text("선택한 식재료로 레시피 옵션을 고릅니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: goToRecipeOption) {
                Text("다음")
                    .font(.headline)
                    .frame(width: 96)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(selectedFoods.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
    
    private var attentionCount: Int {
        allFoods.filter { $0.remainingDays <= 3 }.count
    }
    
    private func summaryCard(title: String, count: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
            
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func filterChip(for filter: SelectFoodsFilter) -> some View {
        let isSelected = selectedFilter == filter
        let count = allFoods.filter { filter.matches($0) }.count
        
        return Button {
            withAnimation(.snappy) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Text(filter.title)
                    .font(.subheadline.weight(isSelected ? .bold : .medium))
                
                Text("\(count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.22) : Color.gray.opacity(0.18))
                    .clipShape(Capsule())
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.green : Color(.secondarySystemGroupedBackground))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "%@ %lld개"), filter.title, Int64(count)))
    }
    
    private func foodSelectionCard(for food: FoodItem) -> some View {
        let isSelected = selectedFoods.contains(where: { $0.id == food.id })
        
        return Button {
            toggleSelection(for: food)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(expiryColor(for: food.expiryState))
                        .frame(width: 12, height: 12)
                        .padding(.top, 4)
                    
                    Spacer()
                    
                    if let badgeTitle = urgencyBadgeTitle(for: food.expiryState) {
                        Text(badgeTitle)
                            .font(.caption2.bold())
                            .foregroundStyle(isSelected ? .white : expiryColor(for: food.expiryState))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(isSelected ? Color.white.opacity(0.22) : expiryColor(for: food.expiryState).opacity(0.14))
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                
                Spacer(minLength: 14)
                
                Text(food.title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                
                Text(food.expiryStatusText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : expiryColor(for: food.expiryState))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .padding(14)
            .background(cardBackground(for: food, isSelected: isSelected))
            .overlay(alignment: .leading) {
                if food.expiryState == .expired || food.expiryState == .today || food.expiryState == .urgent {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(expiryColor(for: food.expiryState))
                        .frame(width: 5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "%@, %@"), food.title, food.expiryStatusText))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private func toggleSelection(for food: FoodItem) {
        withAnimation(.snappy) {
            if selectedFoods.contains(where: { $0.id == food.id }) {
                selectedFoods.removeAll(where: { $0.id == food.id })
            } else {
                selectedFoods.append(food)
            }
        }
    }
    
    private func goToRecipeOption() {
        guard selectedFoods.isEmpty == false else { return }
        let selection = RecipeSelection(foods: selectedFoods)
        navManger.path.append(.recipeOption(selectedFoods: selection))
    }
    
    private func count(for state: FoodExpiryState) -> Int {
        allFoods.filter { $0.expiryState == state }.count
    }
    
    private func urgencyBadgeTitle(for state: FoodExpiryState) -> String? {
        switch state {
        case .expired:
            return String(localized: "기한 지남")
        case .today:
            return String(localized: "오늘")
        case .urgent:
            return String(localized: "임박")
        case .fresh:
            return nil
        }
    }
    
    private func expiryColor(for state: FoodExpiryState) -> Color {
        switch state {
        case .expired:
            return .red
        case .today, .urgent:
            return .orange
        case .fresh:
            return .secondary
        }
    }
    
    @ViewBuilder
    private func cardBackground(for food: FoodItem, isSelected: Bool) -> some View {
        if isSelected {
            Color.green
        } else {
            switch food.expiryState {
            case .expired:
                Color.red.opacity(0.12)
            case .today, .urgent:
                Color.orange.opacity(0.12)
            case .fresh:
                Color(.secondarySystemGroupedBackground)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FoodItem.self, configurations: config)
    
    let sampleFoods = [
        FoodItem(title: "사과", expiryDate: Date().addingTimeInterval(86400 * 3)),
        FoodItem(title: "우유", expiryDate: Date().addingTimeInterval(86400 * 1)),
        FoodItem(title: "계란", expiryDate: Date().addingTimeInterval(86400 * 5)),
        FoodItem(title: "닭가슴살", expiryDate: Date().addingTimeInterval(-86400 * 1)),
        FoodItem(title: "삼겹살", expiryDate: Date().addingTimeInterval(86400 * 7)),
        FoodItem(title: "상추", expiryDate: Date().addingTimeInterval(86400 * 2)),
        FoodItem(title: "요거트", expiryDate: Date().addingTimeInterval(86400 * 4))
    ]
    
    for food in sampleFoods {
        container.mainContext.insert(food)
    }
    
    return SelectFoodsView()
        .modelContainer(container)
        .environmentObject(NavigationManager())
}
