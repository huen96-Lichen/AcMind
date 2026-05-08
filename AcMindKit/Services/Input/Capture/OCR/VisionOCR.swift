import Vision
import Foundation
import CoreImage

// MARK: - Vision OCR

/// 基于 Apple Vision 框架的 OCR 服务
public enum VisionOCR {
    
    // MARK: - Text Recognition
    
    /// 创建文本识别请求
    /// - Parameter completionHandler: 完成回调
    /// - Returns: VNRecognizeTextRequest
    public static func makeTextRecognitionRequest(
        completionHandler: @escaping (VNRequest, Error?) -> Void
    ) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest(completionHandler: completionHandler)
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }
        
        return request
    }
    
    /// 识别图像中的文本
    /// - Parameters:
    ///   - image: 图像数据
    ///   - languages: 识别语言（可选）
    /// - Returns: 识别结果
    public static func recognizeText(
        in image: Data,
        languages: [String]? = nil
    ) async throws -> OCRResult {
        guard let ciImage = CIImage(data: image) else {
            throw OCRError.invalidImage
        }
        
        return try await recognizeText(in: ciImage, languages: languages)
    }
    
    /// 识别图像中的文本
    /// - Parameters:
    ///   - image: CIImage
    ///   - languages: 识别语言（可选）
    /// - Returns: 识别结果
    public static func recognizeText(
        in image: CIImage,
        languages: [String]? = nil
    ) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noResults)
                    return
                }
                
                var blocks: [OCRTextBlock] = []
                var fullText = ""
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else {
                        continue
                    }
                    
                    let text = topCandidate.string
                    let confidence = topCandidate.confidence
                    let boundingBox = observation.boundingBox
                    
                    let block = OCRTextBlock(
                        text: text,
                        confidence: confidence,
                        boundingBox: CGRect(
                            x: boundingBox.origin.x,
                            y: boundingBox.origin.y,
                            width: boundingBox.size.width,
                            height: boundingBox.size.height
                        )
                    )
                    
                    blocks.append(block)
                    fullText += text + "\n"
                }
                
                let result = OCRResult(
                    text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
                    blocks: blocks
                )
                
                continuation.resume(returning: result)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            if let languages = languages {
                request.recognitionLanguages = languages
            }
            
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }
            
            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }
    
    /// 识别图像 URL 中的文本
    /// - Parameter url: 图像 URL
    /// - Returns: 识别结果
    public static func recognizeText(in imageURL: URL) async throws -> OCRResult {
        guard let image = CIImage(contentsOf: imageURL) else {
            throw OCRError.invalidImage
        }
        
        return try await recognizeText(in: image)
    }
    
    /// 识别文件路径中的文本
    /// - Parameter path: 文件路径
    /// - Returns: 识别结果
    public static func recognizeText(inFileAtPath path: String) async throws -> OCRResult {
        let url = URL(fileURLWithPath: path)
        return try await recognizeText(in: url)
    }
}

// MARK: - OCR Result

/// OCR 识别结果
public struct OCRResult: Sendable {
    /// 完整文本
    public let text: String
    /// 文本块列表
    public let blocks: [OCRTextBlock]
    
    public init(text: String, blocks: [OCRTextBlock]) {
        self.text = text
        self.blocks = blocks
    }
}

/// OCR 文本块
public struct OCRTextBlock: Sendable {
    /// 文本内容
    public let text: String
    /// 置信度 (0-1)
    public let confidence: Float
    /// 边界框（归一化坐标）
    public let boundingBox: CGRect
    
    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

// MARK: - OCR Error

public enum OCRError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed(String)
    case noResults
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无效图像"
        case .recognitionFailed(let message):
            return "识别失败: \(message)"
        case .noResults:
            return "无识别结果"
        }
    }
}
