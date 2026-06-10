//
//  GeminiService.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/23/26.
//

import UIKit

class GeminiService {
    enum GeminiServiceError: LocalizedError {
        case invalidImage
        case invalidRequestBody
        case invalidResponse
        case emptyResponse
        
        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "이미지를 분석할 수 있는 형식으로 변환하지 못했습니다."
            case .invalidRequestBody:
                return "요청 데이터를 만들지 못했습니다."
            case .invalidResponse:
                return "서버 응답이 올바르지 않습니다."
            case .emptyResponse:
                return "분석 결과가 비어 있습니다."
            }
        }
    }
    
    
    // 지역 + 함수 종류 = URL
    private let baseURL = "https://example.com/freshkeep-api"
    
    // 기기 언어 확인 (ko, en, ja 등)
    private var currentLang: String {
        return Locale.current.language.languageCode?.identifier ?? "ko"
    }

    func scanImage(image: UIImage) async -> [ResponseItem] {
        do {
            return try await scanImageResult(image: image)
        } catch {
            print("최종 실패: \(error.localizedDescription)")
            return []
        }
    }
    
    func scanImageResult(image: UIImage) async throws -> [ResponseItem] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiServiceError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()
        
        let body: [String: Any] = [
            "image": base64Image,
            "lang": currentLang
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw GeminiServiceError.invalidRequestBody
        }
        
        let url = URL(string: "\(baseURL)/analyzeIngredients")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Timeout 시간 90초 설정 (네트워크 유실 방지)
        request.timeoutInterval = 90
        request.httpBody = jsonData
        
        var retryCount = 2
        while true {
            do {
                print("요청 시작:", request.url?.absoluteString ?? "no url")
                
                // data: 서버가 실제로 보내준 본문, response: 상태 코드, 헤더 같은 메타 정보
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // print위한 코드
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP status:", httpResponse.statusCode)
                }
                

                // “서버가 200번대 성공 응답이 아니네?”까지만 판단함. 500, 503, 400 같은 상태면 invalidResponse를 짐.
                if let httpResponse = response as? HTTPURLResponse, !(200...2999).contains(httpResponse.statusCode) {
                    throw GeminiServiceError.invalidResponse
                }
                
                let decodedResponse = try JSONDecoder().decode(GeminiRawResponse.self, from: data)
                
                if let resultText = decodedResponse.extractedText {
                    print("이미지 분석 성공!: \(resultText)")
                    let parsedItems = parseFoodData(from: resultText)
                    if parsedItems.isEmpty {
                        // 데이터가 비어있으면 에러
                        throw GeminiServiceError.emptyResponse
                    }
                    return parsedItems
                }
                // 통신은 성공했지만, 응답이 정상이 아닌 경우
                throw GeminiServiceError.emptyResponse
            } catch {
                print("이미지 분석 에러 발생: \(error.localizedDescription)")
                print("이미지 분석 에러 발생:", error)
                    print("localized:", error.localizedDescription)

                    if let urlError = error as? URLError {
                        print("URLError code:", urlError.code.rawValue, urlError.code)
                    }

                if retryCount > 0 {
                    print("남은 재시도 횟수 \(retryCount)번. 1초 뒤 다시 시도합니다...")
                    retryCount -= 1
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                } else {
                    print("최종 실패: 모든 재시도에도 응답을 받지 못했습니다.")
                    throw error
                }
            }
        }
    }
    
    func getEXP(foodName: String) async -> Int {
        let body: [String: Any] = [
            "foodName": foodName,
            "lang": currentLang
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return 0 }
        
        
        let url = URL(string: "\(baseURL)/getExpiry")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decodedResponse = try JSONDecoder().decode(GeminiRawResponse.self, from: data)
            
            if let resultText = decodedResponse.extractedText {
                print("소비기한 분석 성공!: \(resultText)")
                let trimmed = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
                return Int(trimmed) ?? 0
            }
        } catch {
            print("소비기한 통신 에러 발생: \(error.localizedDescription)")
        }
        return 0
    }
    
    func getRecipe(options: [String: String]) async -> RecipeResponse? {
        var body: [String: Any] = options
        body["lang"] = currentLang
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        
        let url = URL(string: "\(baseURL)/recommendRecipe")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 90
        
        // scanImage처럼 재시도 로직 추가
        var retryCount = 2
        while true {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // 503이면 재시도
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 503 {
                    throw URLError(.badServerResponse)
                }
                
                let decodedResponse = try JSONDecoder().decode(GeminiRawResponse.self, from: data)
                if let resultText = decodedResponse.extractedText {
                    return parseRecipe(text: resultText)
                }
            } catch {
                if retryCount > 0 {
                    retryCount -= 1
                    print("레시피 재시도 남은 횟수: \(retryCount)회, 2초 후 재시도...")
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 503은 2초 대기
                    continue
                }
                print("레시피 최종 실패: \(error.localizedDescription)")
            }
            return nil
        }
    }
    
    private func parseFoodData(from text: String) -> [ResponseItem] {
        // 1. ```json 과 ``` 사이의 내용만 추출
        let pattern = "```json\\s*([\\s\\S]*?)\\s*```"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        let nsString = text as NSString
        let results = regex?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // 2. 만약 마크다운 형식이면 안의 내용만 쓰고, 아니면 전체를 씀
        var jsonString = text
        if let match = results {
            jsonString = nsString.substring(with: match.range(at: 1))
        }
        
        // 3. JSON 파싱
        guard let data = jsonString.data(using: .utf8) else { return [] }
        
        do {
            // 제미나이가 응답을 { "items": [...] } 형태로 줄 때
            let decoded = try JSONDecoder().decode(rootResponse.self, from: data)
            return decoded.items
        } catch {
            // 제미나이가 [ {...}, {...} ] 배열 형태로 바로 줄 때 대비
            do {
                return try JSONDecoder().decode([ResponseItem].self, from: data)
            } catch {
                print("파싱 실패: \(error)")
                return []
            }
        }
    }
    
    private func parseRecipe(text: String) -> RecipeResponse? {
        // 1. ```json 과 ``` 사이의 내용만 추출
        let pattern = "```json\\s*([\\s\\S]*?)\\s*```"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        let nsString = text as NSString
        let results = regex?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // 2. 만약 마크다운 형식이면 안의 내용만 쓰고, 아니면 전체를 씀
        var jsonString = text
        if let match = results {
            jsonString = nsString.substring(with: match.range(at: 1))
        }
        
        // 3. JSON 파싱
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        do {
            return try JSONDecoder().decode(RecipeResponse.self, from: data)
        } catch {
            print("파싱 실패")
            return nil
        }
    }
}
struct GeminiRawResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable { let text: String }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
    
    var extractedText: String? {
        candidates.first?.content.parts.first?.text
    }
}
