//
//  GeminiService.swift
//  FreshKeep
//
//  Created by 강찬휘 on 3/23/26.
//

import UIKit

struct GeminiAnalysisResult: Sendable {
    var items: [ResponseItem]
    var metrics: GeminiAnalysisMetrics
}

struct GeminiAnalysisMetrics: Codable, Sendable {
    var requestId: String
    var experiment: String
    var model: String?
    var imageMaxDimension: Int?
    var jpegQuality: Double?
    var imageBytes: Int?
    var base64Length: Int?
    var clientImageEncodeMs: Double?
    var clientNetworkRoundTripMs: Double?
    var clientTotalMs: Double?
    var serverTotalMs: Double?
    var geminiMs: Double?
    var serverParsingMs: Double?
    var itemsCount: Int?
    var success: Bool?
    var retryAttempt: Int?
    
    func logLine() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "[PERF] metrics encode failed requestId=\(requestId)"
        }
        
        return "[PERF] \(json)"
    }
}

class GeminiService {
    private let analysisImageMaxDimension = 1280
    private let analysisJPEGQuality = 0.65
    
    enum GeminiServiceError: LocalizedError {
        case invalidImage
        case invalidRequestBody
        case invalidResponse
        case rateLimited(retryAfterSeconds: Int)
        case emptyResponse
        
        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "이미지를 분석할 수 있는 형식으로 변환하지 못했습니다."
            case .invalidRequestBody:
                return "요청 데이터를 만들지 못했습니다."
            case .invalidResponse:
                return "서버 응답이 올바르지 않습니다."
            case .rateLimited(let retryAfterSeconds):
                return "요청 한도를 초과했습니다. \(retryAfterSeconds)초 뒤 다시 시도합니다."
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
    
    func scanImageResult(image: UIImage, requestId: String = UUID().uuidString, experiment: String = "baseline") async throws -> [ResponseItem] {
        try await scanImageAnalysis(
            image: image,
            requestId: requestId,
            experiment: experiment
        ).items
    }
    
    func scanImageAnalysis(
        image: UIImage,
        requestId: String = UUID().uuidString,
        experiment: String = "baseline"
    ) async throws -> GeminiAnalysisResult {
        let encodeStart = Date()
        let resizedImage = resizedImageForAnalysis(image, maxDimension: analysisImageMaxDimension)
        guard let imageData = resizedImage.jpegData(compressionQuality: analysisJPEGQuality) else {
            throw GeminiServiceError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()
        let clientImageEncodeMs = Date().timeIntervalSince(encodeStart) * 1000
        
        let body: [String: Any] = [
            "requestId": requestId,
            "experiment": experiment,
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
        
        var metrics = GeminiAnalysisMetrics(
            requestId: requestId,
            experiment: experiment,
            model: nil,
            imageMaxDimension: analysisImageMaxDimension,
            jpegQuality: analysisJPEGQuality,
            imageBytes: imageData.count,
            base64Length: base64Image.count,
            clientImageEncodeMs: clientImageEncodeMs,
            clientNetworkRoundTripMs: nil,
            clientTotalMs: nil,
            serverTotalMs: nil,
            geminiMs: nil,
            serverParsingMs: nil,
            itemsCount: nil,
            success: nil,
            retryAttempt: nil
        )
        
        var retryCount = 2
        var attempt = 0
        while true {
            do {
                metrics.retryAttempt = attempt
                print("요청 시작:", request.url?.absoluteString ?? "no url", "requestId:", requestId)
                
                // data: 서버가 실제로 보내준 본문, response: 상태 코드, 헤더 같은 메타 정보
                let networkStart = Date()
                let (data, response) = try await URLSession.shared.data(for: request)
                metrics.clientNetworkRoundTripMs = Date().timeIntervalSince(networkStart) * 1000
                
                // print위한 코드
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP status:", httpResponse.statusCode)
                }
                

                // “서버가 200번대 성공 응답이 아니네?”까지만 판단함. 500, 503, 400 같은 상태면 invalidResponse를 짐.
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                    let rateLimitResponse = try? JSONDecoder().decode(GeminiRateLimitResponse.self, from: data)
                    metrics.mergeServerMetrics(rateLimitResponse?.metrics)
                    metrics.success = false
                    if let rateLimitResponse {
                        print("Rate limit response:", rateLimitResponse.message)
                    }
                    throw GeminiServiceError.rateLimited(
                        retryAfterSeconds: retryAfterSeconds(
                            from: httpResponse,
                            data: data,
                            decodedResponse: rateLimitResponse
                        )
                    )
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    throw GeminiServiceError.invalidResponse
                }
                
                let decodedResponse = try JSONDecoder().decode(GeminiRawResponse.self, from: data)
                metrics.mergeServerMetrics(decodedResponse.metrics)
                
                if let resultText = decodedResponse.extractedText {
                    print("이미지 분석 성공!: \(resultText)")
                    let parsedItems = parseFoodData(from: resultText)
                    if parsedItems.isEmpty {
                        // 데이터가 비어있으면 에러
                        throw GeminiServiceError.emptyResponse
                    }
                    metrics.itemsCount = parsedItems.count
                    metrics.success = true
                    return GeminiAnalysisResult(items: parsedItems, metrics: metrics)
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
                    let retryDelaySeconds = retryDelaySeconds(for: error)
                    print("남은 재시도 횟수 \(retryCount)번. \(retryDelaySeconds)초 뒤 다시 시도합니다...")
                    retryCount -= 1
                    attempt += 1
                    try? await Task.sleep(nanoseconds: UInt64(retryDelaySeconds) * 1_000_000_000)
                    continue
                } else {
                    metrics.success = false
                    print(metrics.logLine())
                    print("최종 실패: 모든 재시도에도 응답을 받지 못했습니다.")
                    throw error
                }
            }
        }
    }
    
    private func retryDelaySeconds(for error: Error) -> Int {
        if case GeminiServiceError.rateLimited(let retryAfterSeconds) = error {
            return max(retryAfterSeconds, 10)
        }
        
        return 1
    }
    
    private func retryAfterSeconds(
        from response: HTTPURLResponse,
        data: Data,
        decodedResponse: GeminiRateLimitResponse?
    ) -> Int {
        if let retryAfterValue = response.value(forHTTPHeaderField: "Retry-After"),
           let retryAfterSeconds = Int(retryAfterValue) {
            return max(retryAfterSeconds, 10)
        }
        
        if let retryAfterSeconds = decodedResponse?.retryAfterSeconds {
            return max(retryAfterSeconds, 10)
        }
        
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let retryAfterSeconds = json["retryAfterSeconds"] as? Int
        else {
            return 10
        }
        
        return max(retryAfterSeconds, 10)
    }
    
    private func resizedImageForAnalysis(_ image: UIImage, maxDimension: Int) -> UIImage {
        let pixelWidth = image.cgImage?.width ?? Int(image.size.width * image.scale)
        let pixelHeight = image.cgImage?.height ?? Int(image.size.height * image.scale)
        let longestSide = max(pixelWidth, pixelHeight)
        
        guard longestSide > maxDimension else {
            return image
        }
        
        let ratio = CGFloat(maxDimension) / CGFloat(longestSide)
        let targetSize = CGSize(
            width: CGFloat(pixelWidth) * ratio,
            height: CGFloat(pixelHeight) * ratio
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
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
    let metrics: GeminiAnalysisMetrics?
    
    var extractedText: String? {
        candidates.first?.content.parts.first?.text
    }
}

struct GeminiRateLimitResponse: Codable {
    let error: String
    let message: String
    let retryAfterSeconds: Int
    let requestId: String
    let metrics: GeminiAnalysisMetrics?
}

private extension GeminiAnalysisMetrics {
    mutating func mergeServerMetrics(_ serverMetrics: GeminiAnalysisMetrics?) {
        guard let serverMetrics else { return }
        
        model = serverMetrics.model ?? model
        imageMaxDimension = serverMetrics.imageMaxDimension ?? imageMaxDimension
        serverTotalMs = serverMetrics.serverTotalMs ?? serverTotalMs
        geminiMs = serverMetrics.geminiMs ?? geminiMs
        serverParsingMs = serverMetrics.serverParsingMs ?? serverParsingMs
        itemsCount = serverMetrics.itemsCount ?? itemsCount
        success = serverMetrics.success ?? success
    }
}
