//
//  CaptureManager.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/19/26.
//

import Foundation
import SwiftData
import UIKit

@MainActor // UI와 관련된 데이터(Swift Data 포함)는 메인 쓰레드에서 안전하게 처리함
class CaptureManager {
    static let shared = CaptureManager()
    private init() {}
    
    /// GPT 분석 결과를 바탕으로 전체 세션과 아이템들을 저장하는 메인 함수
    /// - Parameters:
    ///     - originalImage: 카메라로 찍거나 앨범에서 가져온 원본 UIImage
    ///     - gptResults: OpenAIService로부터 받은 분석 결과 리스트
    ///     - context: View에서 전달 받은 SwiftData의 ModelContext
    func saveCapturedSession(originalImage: UIImage, gptResults: [ResponseItem], context: ModelContext) {
        // 1. 이미지 파일을 로컬에 저장하고 파일명을 받아옵니다.
        guard let fileName = saveImageToDisk(image: originalImage) else {
            print("아마자 저장 실패")
            return
        }
        
        // 2. 새로운 captrue session 생성
        let newSession = CaptureSession(originalImage: fileName)
        
        // 3. context(작업대?)에 세션을 등록
        context.insert(newSession)
        
        // 4. GPT가 찾아낸 상품 개수만큼 반복하며 FoodItem 생성
        for result in gptResults {
            let foodName = String(result.name)
            
            let descriptor = FetchDescriptor<Category>(
                predicate: #Predicate<Category> { category in
                    category.name == foodName
                }
            )
            
            let categoryList = try? context.fetch(descriptor)
            
            let category: Category
            if let found = categoryList?.first {
                // 기존에 있는 카테고리면
                category = found
                if result.isEdited {
                    category.userCustomLife = result.expiryDays
                }
            } else {
                let newCategory = Category(
                    name: foodName,
                    defaultShelLife: result.expiryDays,
                    userCustomLife: result.isEdited ? result.expiryDays : nil
                )
                context.insert(newCategory)
                category = newCategory
            }
            
            // 소비기한 계산 (현재 날짜 + GPT가 준 expiryDays)
            let calculatedExpiryDate = Calendar.current.date(
                byAdding: .day,
                value: result.expiryDays,
                to: Date()
            ) ?? Date()
            
            // FoodItem instance 생성
            let foodItem = FoodItem(
                title: result.name,
                expiryDate: calculatedExpiryDate
            )
            
            foodItem.category = category
            
            // 5. 관계 연결
            newSession.recognizedItems?.append(foodItem)
        }
        print("세션 생성 및 \(gptResults.count)개의 아이템 저장 완료")
        // 함수 맨 끝에 추가 (print문 위아래로 넣어보세요)
        do {
            // 1. 모든 카테고리 가져오기
            let categoryFetch = FetchDescriptor<Category>()
            let allCategories = try context.fetch(categoryFetch)
            
            print("\n--- 📦 현재 저장된 카테고리 & 아이템 현황 ---")
            for category in allCategories {
                let itemsCount = category.foodItems?.count ?? 0
                print("📍 카테고리: [\(category.name)] (권장기한: \(category.defaultShelLife)일)")
                print("   ㄴ 연결된 실물 아이템 수: \(itemsCount)개")
                
                // 해당 카테고리에 속한 아이템 이름들도 보고 싶다면?
                category.foodItems?.forEach { item in
                    print("      - 상품명: \(item.title) (소비기한: \(item.expiryDate.formatted(date: .numeric, time: .omitted)))")
                }
            }
            print("------------------------------------------\n")
            
        } catch {
            print("❌ 데이터 확인 중 에러 발생: \(error.localizedDescription)")
        }
    }
    
    private func saveImageToDisk(image: UIImage) -> String? {
        // 이미지 압축 (80%압축의 JPEG)
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        // 중복 방지를 위한 고유 파일명 생성
        let fileName = "IMG_\(UUID().uuidString).jpg"
        
        // 폴더 경로를 가져옴
        let fileManager = FileManager.default
        // 앱의 Documents 디렉토리 경로 찾기
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {return nil}
        
        // 만약 Document Path가 없으면, 생성
        if !fileManager.fileExists(atPath: documentsPath.path) {
            try? fileManager.createDirectory(at: documentsPath, withIntermediateDirectories: true)
        }

        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            // 실제 파일 쓰기
            try data.write(to: fileURL)
            return fileName // DB에는 파일명만 저장.
        } catch {
            print("파일 쓰기 에러\(error)")
            return nil
        }
    }
    
    /// 로컬에 저장된 파일명을 가지고 UIImage를 불러오는 함수
    /// - Parameter fileName: DB에 저장된 파일명 (예: IMG_XXX.jpg)
    /// - Returns: 불러오기에 성공하면 UIImage, 실패하면 nil
    func loadImageFromDisk(fileName: String) -> UIImage? {
        // 1. 앱의 Documents 디렉토리 경로를 동적으로 가져옵니다. (바뀌어도 상관없음)
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Documents 폴더를 찾을 수 없습니다.")
            return nil
        }
        
        // 2. 현재 Documents 경로와 파일명을 결합하여 최종 URL을 만듭니다.
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        // 3. 해당 경로의 파일을 UIImage로 변환하여 리턴합니다.
        // UIImage(contentsOfFile:)은 로컬 파일을 읽을 때 가장 빠르고 효율적입니다.
        if fileManager.fileExists(atPath: fileURL.path) {
            return UIImage(contentsOfFile: fileURL.path)
        } else {
            print("❌ 파일이 해당 경로에 존재하지 않습니다: \(fileURL.path)")
            return nil
        }
    }
}
