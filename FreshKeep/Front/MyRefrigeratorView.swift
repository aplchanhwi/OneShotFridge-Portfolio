//
//  ShowFoodList.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/23/26.
//

import SwiftUI
import SwiftData

struct MyRefrigeratorView: View {
    @Query(
        filter: #Predicate<FoodItem> { $0.isConsumed == false },
        sort: \FoodItem.expiryDate,
        order:.forward
    )
    private var allFoodList: [FoodItem]
    
    // 냉장고 화면의 시트 표시 상태와 저장 액션은 ViewModel이 담당합니다.
    // View는 목록 표시와 버튼 연결에 집중합니다.
    @StateObject private var viewModel = MyRefrigeratorViewModel()
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var navManager: NavigationManager
    
    private var filteredFoodList: [FoodItem] {
        viewModel.filteredFoods(from: allFoodList)
    }
    
    var body: some View {
        Group {
            if allFoodList.isEmpty {// 데이터가 없을 때 보여줄 빈 화면
                emptyRefrigeratorView
            } else {
                List {
                    Section {
                        dashboardView
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    
                    Section {
                        filterChipsView
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    
                    Section {
                        if filteredFoodList.isEmpty {
                            filteredEmptyView
                        } else {
                            ForEach(filteredFoodList) { item in
                                foodRow(for: item)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(Text("우리 집 식재료"))
        .sheet(
            item: $viewModel.selectedFoodItem,
            onDismiss: {print("수정 시트가 닫혔습니다!") }
        ) { item in
            FoodEditView(foodItem: item)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $viewModel.isAddViewShown) {
            // FoodAddView는 입력값만 넘겨주는 공용 시트입니다.
            // 냉장고에서는 전달받은 값을 즉시 SwiftData에 FoodItem으로 저장합니다.
            FoodAddView(title: "식재료 추가") { name, expiryDays in
                viewModel.addFood(name: name, expiryDays: expiryDays, context: modelContext)
            }
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.showAddView()
                    } label: {
                        Label("식재료 추가", systemImage: "plus")
                    }
                    
                    Button {
                        navManager.path.append(.smartRecipe)
                    } label: {
                        Label("레시피 만들기", systemImage: "fork.knife")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            NotificationManager.shared.updateFoodNotifications(allFoodList: allFoodList)
        }
        .onChange(of: notificationRefreshKey) { _, _ in
            // 수동 추가, 소비 처리, 소비기한 수정으로 목록 상태가 바뀌면 예약 알림도 다시 계산합니다.
            NotificationManager.shared.updateFoodNotifications(allFoodList: allFoodList)
        }
        
    }
    
    // onChange가 FoodItem 배열 자체의 내부 변경을 안정적으로 감지하도록 만든 비교용 키입니다.
    // 알림에 영향을 주는 id, expiryDate, isConsumed만 문자열로 묶어 추적합니다.
    private var notificationRefreshKey: [String] {
        allFoodList.map {
            "\($0.id.uuidString)-\($0.expiryDate.timeIntervalSince1970)-\($0.isConsumed)"
        }
    }
    
    private var emptyRefrigeratorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "refrigerator")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("냉장고가 텅 비었어요!")
                .font(.title2.bold())
            Text("새로운 식재료를 추가해 보세요.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var dashboardView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("먼저 확인할 식재료 \(viewModel.attentionCount(in: allFoodList))개")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("기한이 임박한 항목만 빠르게 모아볼 수 있어요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 10) {
                summaryCard(
                    title: String(localized: "기한 지남"),
                    count: viewModel.count(for: FoodExpiryState.expired, in: allFoodList),
                    tint: .red
                )
                summaryCard(
                    title: String(localized: "오늘까지"),
                    count: viewModel.count(for: FoodExpiryState.today, in: allFoodList),
                    tint: .orange
                )
                summaryCard(
                    title: String(localized: "3일 이내"),
                    count: viewModel.count(for: FoodExpiryState.urgent, in: allFoodList),
                    tint: .blue
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RefrigeratorFilter.allCases) { filter in
                    filterChip(for: filter)
                }
            }
        }
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
        .padding(.vertical, 28)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func filterChip(for filter: RefrigeratorFilter) -> some View {
        let isSelected = viewModel.selectedFilter == filter
        let count = viewModel.count(for: filter, in: allFoodList)
        
        return Button {
            withAnimation(.snappy) {
                viewModel.selectFilter(filter)
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
        .accessibilityLabel("\(filter.title) \(count)개")
    }
    
    private func foodRow(for item: FoodItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(colorForExpiryState(item.expiryState).opacity(0.18))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                Text(item.expiryStatusText)
                    .font(.subheadline)
                    .foregroundColor(colorForExpiryState(item.expiryState))
            }
            
            Spacer()
            
            Menu {
                Button("식사 완료") {
                    withAnimation {
                        viewModel.markAsConsumed(item, context: modelContext)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.showEditView(for: item)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                withAnimation {
                    viewModel.markAsConsumed(item, context: modelContext)
                }
            } label : {
                Image(systemName: "fork.knife")
            }
            .tint(.green)
        }
    }
    
    private func colorForExpiryState(_ state: FoodExpiryState) -> Color {
        switch state {
        case .expired:
            return .red
        case .today:
            return .orange
        case .urgent:
            return .orange
        case .fresh:
            return .secondary
        }
    }
}
#Preview {
    // 1. 프리뷰를 위한 가짜 컨테이너 생성 (메모리 상에만 존재)
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FoodItem.self, configurations: config)
    
    // 2. 가짜 데이터 집어넣기 (찬휘 님이 테스트할 데이터들)
    // 2. 가짜 데이터 집어넣기 (다양한 날짜 케이스 총집합!)
    let sampleItems = [
        // 🚨 유통기한 지남 (빨간색 테스트용)
        FoodItem(title: "먹다 남은 치킨", expiryDate: Date().addingTimeInterval(-86400 * 5)), // 5일 지남
        FoodItem(title: "요거트", expiryDate: Date().addingTimeInterval(-86400 * 1)), // 1일 지남
        
        // ⚠️ 유통기한 임박 (주황색 테스트용)
        FoodItem(title: "식빵", expiryDate: Date()), // 오늘까지
        FoodItem(title: "우유", expiryDate: Date().addingTimeInterval(86400 * 1)), // 1일 남음
        FoodItem(title: "콩나물", expiryDate: Date().addingTimeInterval(86400 * 2)), // 2일 남음
        
        // 🍏 유통기한 넉넉함 (회색/기본색 테스트용)
        FoodItem(title: "두부", expiryDate: Date().addingTimeInterval(86400 * 5)), // 5일 남음
        FoodItem(title: "계란", expiryDate: Date().addingTimeInterval(86400 * 14)), // 2주 남음
        FoodItem(title: "냉동 만두", expiryDate: Date().addingTimeInterval(86400 * 90)), // 약 3달 남음
        FoodItem(title: "참치캔", expiryDate: Date().addingTimeInterval(86400 * 365)) // 1년 남음
    ]
    
    for item in sampleItems {
        container.mainContext.insert(item)
    }
    
    // 3. 뷰를 반환하면서 컨테이너와 매니저 주입
    return NavigationStack {
        MyRefrigeratorView()
            .modelContainer(container) // 가짜 데이터 주입
            .environmentObject(NavigationManager()) // 내비게이션 매니저 주입
    }
}
