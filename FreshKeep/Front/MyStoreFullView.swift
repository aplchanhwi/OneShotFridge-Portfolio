//
//  MyStoreView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 4/1/26.
//

import SwiftUI
import StoreKit

struct MyStoreFullView: View {
    @Environment(\.dismiss) var dismiss
    @State var showManageSubscriptionSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 0){
            Spacer()
            SubscriptionStoreView(groupID: "22057210") {
                VStack(spacing: 20) {
                        // 앱 로고나 아이콘
                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                            .padding(.top, 40)
                        
                        Text(String(localized: "원샷 냉장고 Premium"))
                            .font(.largeTitle.bold())
                        
                        VStack(alignment: .leading, spacing: 15) {
                            BenefitRow(
                                icon: "photo.stack",
                                title: String(localized: "무제한 사진 분석"),
                                description: String(localized: "광고 없이 한 번에 여러 개의 식재료를 등록하세요.")
                            )
                            BenefitRow(icon: "fork.knife",
                                       title: String(localized: "스마트 레시피 추천"),
                                       description: String(localized: "냉장고 속 식재료로 새로운 요리에 도전해보세요.")
                            )
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 20)
                    }
            }
            
            .subscriptionStoreControlStyle(.prominentPicker)
            .subscriptionStoreButtonLabel(.singleLine)
            .subscriptionStorePolicyDestination(url: URL(string: "https://github.com/aplchanhwi/OneShotFridge-Support/blob/main/PrivacyPolicy.md")!, for: .privacyPolicy)
            .subscriptionStorePolicyDestination(url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!, for: .termsOfService)
            .onInAppPurchaseCompletion { product, result in
                // 1단계: 애플 서버와의 통신 결과 확인
                switch result {
                case .success(let purchaseResult):
                    
                    // 2단계: 사용자의 실제 구매 행동 확인
                    switch purchaseResult {
                    case .success(let verificationResult):
                        
                        // 3단계: 영수증 검증
                        if case .verified(let transaction) = verificationResult {
                            print("✅ 진짜 결제 완료: \(transaction.productID)")
                            
                            Task {
                                await transaction.finish() // 트랜잭션 종료 처리
                                dismiss()
                            }
                        } else if case .unverified(let transaction, let error) = verificationResult {
                            print("❌ 영수증 검증 실패: \(transaction.productID), 에러: \(error)")
                        }
                        
                    case .userCancelled:
                        print("👤 사용자가 결제창을 닫거나 취소함")
                        
                    case .pending:
                        print("⏳ 결제 승인 대기 중 (부모님 동의 필요 등)")
                        
                    @unknown default:
                        break
                    }
                    
                case .failure(let error):
                    // 통신 실패나 스토어킷 자체 에러
                    print("❌ 결제 시스템 에러: \(error.localizedDescription)")
                }
            }
            
            Button("구독 관리") { showManageSubscriptionSheet = true }
        }
        .background {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea() // 화면 끝까지 꽉 채우기
        }
        .navigationBarBackButtonHidden(true)
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptionSheet)
    }
}

#Preview {
    MyStoreFullView()
}
