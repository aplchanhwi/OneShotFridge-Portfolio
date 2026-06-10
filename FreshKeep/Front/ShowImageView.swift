//
//  ShowImageView.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/11/26.
//

import SwiftUI
import Vision

struct ShowImageView: View {
    let mainImage: UIImage
    @EnvironmentObject var navManager: NavigationManager
    @EnvironmentObject var storeManager: StoreManager
    
    /// Vision용
    @State private var analyzedItems: [AnalyzedItem] = []
    @State private var isProcessing = false
    @State private var isShowingStore = false
    
    var body: some View {
        VStack{
            Image(uiImage: mainImage)
                .resizable() // 크기 조절 가능하게
                .scaledToFit()
                .frame(maxWidth: .infinity)
            //            .maxHeight(400) // 너무 커지지 않게 제한
                .cornerRadius(15)
                .shadow(radius: 5)
                .padding()
            
            Button(
                action: {
                    if storeManager.isPremium { // 구독자라면 바로 뷰 이동
                        navManager.tempCroppedImages = analyzedItems
                        navManager.path.append(.geminiResult)
                    } else {
                        isShowingStore = true // 구독자가 아니라면 구독 View Show
                    }
            },
                label: {
                Text("사진 한장으로 분석하기").bold()
            })
            .buttonStyle(GreenButtonStyle())
            .padding()
        }
        .onAppear {
            print("🚀 [Debug] onAppear: runVisionPipeLine 실행 시도")
            runVisionPipeLine(InputImage: mainImage)
        }
        .sheet(isPresented: $isShowingStore) {
            MyStoreSheetView(onSuccess: { // onCall 함수: 광고 다 보거나, 결제하면 아래의 2줄 실행
                navManager.tempCroppedImages = analyzedItems
                navManager.path.append(.geminiResult)
            })
        }
    }
    // MARK: - VISION PIPELINE
    private func runVisionPipeLine(InputImage: UIImage) {
        print("🔍 [Debug] runVisionPipeLine: CGImage 변환 시도 중...")
        
        guard let cgImage = InputImage.cgImage else { return }
        isProcessing = true
        
        // 1단계: 사물 감지 요청 (Saliency)
        // - 이미지 내에서 '시각적으로 눈에 띄는' 물체들의 영역을 찾습니다.
        let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        
        
        // 2단계: 사물 분류 요청 (Classification)
        // - 사진 속 물체가 무엇인지 애플의 학습된 모델로 판단합니다.
        let classifyRequest = VNClassifyImageRequest()
        
        // ⭐️ 디버깅 3: 핸들러 생성 확인 (여기서 터질 확률 높음)
        print("🔍 [Debug] runVisionPipeLine: VNImageRequestHandler 생성 시도 중...")
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // ⭐️ 디버깅 4: Vision 요청 실행 확인
                    print("🔍 [Debug] global.async: handler.perform 실행 시도 중...")
                
                // 두 가지 요청을 동시에 실행
                try handler.perform([saliencyRequest, classifyRequest])
                
                // 1. 이미지 전체에 대한 1차 필터링
                if let classification = classifyRequest.results {
                    let topResult = classification.first
                    // 식재료와 전혀 상관없는 카테고리가 90%이상 확실하다면 경고
                    if let label = topResult?.identifier, label.contains("dog") || label.contains("car") {
                        print("⚠️ 경고: 식재료가 아닌 것 같습니다 (\(label))")
                    }
                }
                // ⭐️ 디버깅 5: 사물 영역 추출 확인
                                print("🔍 [Debug] global.async: salientObjects 추출 시도 중...")
                // 2. 사물 영역(Bounding Box) 추출 및 자르기
                guard let salicencyResults = saliencyRequest.results?.first as? VNSaliencyImageObservation,
                      let objects = salicencyResults.salientObjects else {return}
                
                var tempResults: [AnalyzedItem] = []
                
                for object in objects {
                    // ⭐️ 디버깅 6: 크롭 시도 확인
                                        print("🔍 [Debug] 반복문[\(index)]: cropImage 호출 시도...")
                    // Vision의 좌표계(0~1, 하단 시작)를 기반으로 이미지 크롭
                    if let croppedImg = self.cropImage(InputImage, to: object.boundingBox){
                        // 3. 잘린 조각별로 '이게 뭔지' 다시 판단 (2단계 로컬 판단)
                        let pieceHandler = VNImageRequestHandler(cgImage: croppedImg.cgImage!, options: [:])
                        let pieceClassifyRequest = VNClassifyImageRequest()
                        try? pieceHandler.perform([pieceClassifyRequest])
                        
                        if let pieceResult = pieceClassifyRequest.results?.first as? VNClassificationObservation {
                            let confidence = pieceResult.confidence
                            let name = pieceResult.identifier
                            
                            // 조건: 신뢰도가 80% 미만이거나, 모호한 이름이면 GPT 분석 대상으로 분류
                            let needsGPT = confidence < 0.8
                            
                            let item = AnalyzedItem(
                                croppedImage: croppedImg,
                                name: name,
                                confidence: confidence,
                                needsGPT: needsGPT
                            )
                            tempResults.append(item)
                        }
                    }
                }
                
                // UI 업데이트는 메인 스레드에서
                DispatchQueue.main.async {
                    self.analyzedItems = tempResults
                    self.isProcessing = false
                }
                
            } catch {
                print("Vision 파이프라인 실행 중 오류 발생: \(error)")
                DispatchQueue.main.async { self.isProcessing = false }
            }
        }
        
    }
    
    // MARK: - 이미지 크로핑 유틸리티
    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        print("cropImage function called")
        guard let cgImage = image.cgImage else {return nil}
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        // Vision 좌표계(Normalized 0~1)를 실제 픽셀 좌표로 변환
        // 원점(Origin)이 왼쪽 하단이므로 Y축을 뒤집어야 한다
        let rectX = rect.minX * width
        let rectWidth = rect.width * width
        let rectHeight = rect.height * height
        let rectY = (1.0 - rect.maxY) * height
        
        let cropRect = CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight)
        
        guard let croppedCgImage = cgImage.cropping(to: cropRect) else {return nil}
        return UIImage(cgImage: croppedCgImage)
    }
}
#Preview {
    NavigationStack{
        // 시스템 아이콘(애플 기본 제공)을 UIImage로 변환해서 전달
        ShowImageView(mainImage: UIImage(systemName: "photo.fill") ?? UIImage())
    }
}
