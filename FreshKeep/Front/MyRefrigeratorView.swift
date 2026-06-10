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
    
    var body: some View {
        VStack {
            if allFoodList.isEmpty {// 데이터가 없을 때 보여줄 빈 화면
                VStack(spacing: 20) {
                    Image(systemName: "refrigerator")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("냉장고가 텅 비었어요!")
                        .font(.title2.bold())
                    Text("새로운 식재료를 추가해 보세요.")
                        .foregroundColor(.secondary)
                }
                .padding()} else {
                    List(allFoodList) { item in
                        HStack {
                            HStack{
                                VStack(alignment: .leading) {
                                    Text(item.title) // 우유
                                        .font(.headline)
                                    Text(item.expiryStatusText) // 몇일 남았습니다
                                        .font(.subheadline)
                                        .foregroundColor(colorForExpiry(item.expiryStatusText))
                                }
                                Spacer()
                            }
                            .contentShape(.rect)
                            .onTapGesture {
                                viewModel.showEditView(for: item)
                            }
                            .overlay(alignment: .trailing){
                                Menu(content: {
                                    Button("식사 완료") {
                                        print("eat completed")
                                        withAnimation {
                                            viewModel.markAsConsumed(item, context: modelContext)
                                        }
                                    }
                                }){
                                    Label("", systemImage: "ellipsis")
                                }.buttonStyle(.plain)
                            }
                            .foregroundColor(.white) // 버튼 강조색
                            .contentShape(Rectangle()) // 버튼 영역 최적화
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
    
    private func colorForExpiry(_ status: String) -> Color {
        // 1. 가장 먼저 '지남' 상태를 필터링 (가장 시급하니까요!)
        if status.contains("지났") || status.contains("overdue")  {
            return .red
        }
        
        // 2. '오늘'인 경우도 숫자가 없으므로 따로 처리
        if status.contains("오늘") || status.contains("today") {
            return .orange
        }
        
        // 3. 문자열에서 숫자만 쏙 뽑아내기 (예: "31일 남음" -> "31" -> 정수 31)
        let numberString = status.filter { $0.isWholeNumber }
        
        if let days = Int(numberString) {
            if days <= 2 {
                return .orange // 1일, 2일 남았을 때
            } else {
                return .secondary // 3일 이상 (31일 포함!) 넉넉할 때
            }
        }
        
        // 숫자가 아예 없는 예외 상황일 경우 기본색 반환
        return .secondary
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
