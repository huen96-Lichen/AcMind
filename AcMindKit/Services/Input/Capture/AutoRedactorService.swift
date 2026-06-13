import Foundation
import Vision
import AppKit

public protocol ScreenshotRedacting: Sendable {
    func redact(_ image: NSImage, mode: CensorMode) async -> NSImage
}

public enum CensorMode: Int, Codable, CaseIterable {
    case pixelate = 0
    case blur = 1
    case solid = 2
    case erase = 3
    
    public var displayName: String {
        switch self {
        case .pixelate: return "像素化"
        case .blur: return "模糊"
        case .solid: return "纯色填充"
        case .erase: return "智能擦除"
        }
    }
}

public struct RedactionRegion: Sendable {
    public let boundingBox: CGRect
    public let text: String?
    public let type: RedactionType
    
    public init(boundingBox: CGRect, text: String? = nil, type: RedactionType) {
        self.boundingBox = boundingBox
        self.text = text
        self.type = type
    }
}

public enum RedactionType: String, Codable, CaseIterable, Sendable {
    case email
    case phone
    case ssn
    case creditCard
    case cvv
    case expiry
    case ipv4
    case awsKey
    case secret
    case hexKey
    case bearer
    case face
    case person
    
    public var displayName: String {
        switch self {
        case .email: return "邮箱"
        case .phone: return "电话号码"
        case .ssn: return "社保号"
        case .creditCard: return "信用卡"
        case .cvv: return "CVV"
        case .expiry: return "有效期"
        case .ipv4: return "IP 地址"
        case .awsKey: return "AWS Key"
        case .secret: return "密钥/Token"
        case .hexKey: return "Hex Key"
        case .bearer: return "Bearer Token"
        case .face: return "人脸"
        case .person: return "人物"
        }
    }
}

public actor AutoRedactorService: ScreenshotRedacting {
    
    public static let shared = AutoRedactorService()
    private static let logger = AcMindLogger(category: .capture)
    
    private let sensitivePatterns: [(name: RedactionType, pattern: NSRegularExpression)] = {
        let patterns: [(RedactionType, String)] = [
            (.email, #"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"#),
            (.phone, #"(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)\d{3}[-.\s]?\d{4}"#),
            (.ssn, #"\b\d{3}[-\s]\d{2}[-\s]\d{4}\b"#),
            (.creditCard, #"\d{4}[-\s]*\d{4}[-\s]*\d{4}[-\s]*\d{1,7}"#),
            (.creditCard, #"\d{4}[-\s]*\d{6}[-\s]*\d{5}"#),
            (.cvv, #"(?:CVV|CVC|CSC|CCV)\s*:?\s*\d{3,4}"#),
            (.ipv4, #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#),
            (.awsKey, #"\b(?:AKIA|ABIA|ACCA|ASIA)[0-9A-Z]{16}\b"#),
            (.secret, #"(?:password|passwd|secret|token|api[_-]?key|access[_-]?key|private[_-]?key)\s*[:=]\s*\S+"#),
            (.hexKey, #"\b[0-9a-fA-F]{32,}\b"#),
            (.bearer, #"Bearer\s+[A-Za-z0-9\-._~+/]+=*"#),
        ]
        return patterns.compactMap { (type, pat) in
            guard let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) else { return nil }
            return (type, regex)
        }
    }()

    public func redact(_ image: NSImage, mode: CensorMode) async -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        var regions: [RedactionRegion] = []
        let selectionRect = NSRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)

        let piiRegions = await redactPII(in: image, selectionRect: selectionRect)
        regions.append(contentsOf: piiRegions)

        let faceRegions = await detectFaces(in: image, selectionRect: selectionRect)
        regions.append(contentsOf: faceRegions)

        let personRegions = await detectPeople(in: image, selectionRect: selectionRect)
        regions.append(contentsOf: personRegions)

        guard regions.isEmpty == false else {
            return image
        }

        return await applyRedactions(to: image, regions: regions, mode: mode)
    }
    
    public func redactPII(in image: NSImage, selectionRect: NSRect) async -> [RedactionRegion] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        
        var regions: [RedactionRegion] = []
        
        do {
            let ciImage = CIImage(cgImage: cgImage)
            let ocrResult = try await VisionOCR.recognizeText(in: ciImage)
            
            for block in ocrResult.blocks {
                let text = block.text
                
                for (type, regex) in sensitivePatterns {
                    let nsText = text as NSString
                    let range = NSRange(location: 0, length: nsText.length)
                    
                    for match in regex.matches(in: text, options: [], range: range) {
                        let normalizedBox = normalizeBoundingBox(block.boundingBox, in: selectionRect)
                        let matchedText = nsText.substring(with: match.range)
                        regions.append(RedactionRegion(
                            boundingBox: normalizedBox,
                            text: matchedText,
                            type: type
                        ))
                    }
                }
            }
        } catch {
            Self.logger.error("AutoRedactor: OCR failed - \(error)")
        }
        
        return regions
    }
    
    public func detectFaces(in image: NSImage, selectionRect: NSRect) async -> [RedactionRegion] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let regions = observations.map { observation -> RedactionRegion in
                    let normalizedBox = self.convertVisionBoundingBox(observation.boundingBox, in: selectionRect)
                    return RedactionRegion(boundingBox: normalizedBox, type: .face)
                }
                
                continuation.resume(returning: regions)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    public func detectPeople(in image: NSImage, selectionRect: NSRect) async -> [RedactionRegion] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNDetectHumanRectanglesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNHumanObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let regions = observations.map { observation -> RedactionRegion in
                    let normalizedBox = self.convertVisionBoundingBox(observation.boundingBox, in: selectionRect)
                    return RedactionRegion(boundingBox: normalizedBox, type: .person)
                }
                
                continuation.resume(returning: regions)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    public func applyRedactions(to image: NSImage, regions: [RedactionRegion], mode: CensorMode = .pixelate) async -> NSImage {
        guard !regions.isEmpty else { return image }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return image
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        for region in regions {
            let padding: CGFloat = 4
            let x = region.boundingBox.origin.x * CGFloat(width) - padding
            let y = (1 - region.boundingBox.origin.y - region.boundingBox.height) * CGFloat(height) - padding
            let w = region.boundingBox.width * CGFloat(width) + padding * 2
            let h = region.boundingBox.height * CGFloat(height) + padding * 2
            
            let rect = CGRect(x: x, y: y, width: w, height: h)
            
            switch mode {
            case .pixelate:
                pixelateRegion(in: context, rect: rect)
            case .blur:
                blurRegion(in: context, rect: rect, image: cgImage)
            case .solid:
                context.setFillColor(NSColor(white: 0, alpha: 1).cgColor)
                context.fill(rect)
            case .erase:
                eraseRegion(in: context, rect: rect, image: cgImage)
            }
        }
        
        guard let newCGImage = context.makeImage() else {
            return image
        }
        
        return NSImage(cgImage: newCGImage, size: image.size)
    }
    
    private func normalizeBoundingBox(_ box: CGRect, in selectionRect: NSRect) -> CGRect {
        let normalizedX = (box.origin.x * selectionRect.width) / 1000
        let normalizedY = (box.origin.y * selectionRect.height) / 1000
        let normalizedW = (box.width * selectionRect.width) / 1000
        let normalizedH = (box.height * selectionRect.height) / 1000
        
        return CGRect(x: normalizedX, y: normalizedY, width: normalizedW, height: normalizedH)
    }

    private func convertVisionBoundingBox(_ box: CGRect, in selectionRect: NSRect) -> CGRect {
        CGRect(
            x: box.origin.x * selectionRect.width,
            y: box.origin.y * selectionRect.height,
            width: box.width * selectionRect.width,
            height: box.height * selectionRect.height
        )
    }
    
    private func pixelateRegion(in context: CGContext, rect: CGRect) {
        let pixelSize: CGFloat = 10
        let startX = Int(rect.origin.x / pixelSize) * Int(pixelSize)
        let startY = Int(rect.origin.y / pixelSize) * Int(pixelSize)
        let endX = Int((rect.origin.x + rect.width) / pixelSize) * Int(pixelSize)
        let endY = Int((rect.origin.y + rect.height) / pixelSize) * Int(pixelSize)
        
        guard let data = context.data else { return }
        let ptr = data.bindMemory(to: UInt8.self, capacity: context.width * context.height * 4)
        let bytesPerRow = context.width * 4
        
        for y in stride(from: startY, to: endY, by: Int(pixelSize)) {
            for x in stride(from: startX, to: endX, by: Int(pixelSize)) {
                guard x >= 0, x < context.width, y >= 0, y < context.height else { continue }
                
                let idx = y * bytesPerRow + x * 4
                let r = ptr[idx]
                let g = ptr[idx + 1]
                let b = ptr[idx + 2]
                
                for dy in 0..<Int(pixelSize) {
                    for dx in 0..<Int(pixelSize) {
                        let nx = x + dx
                        let ny = y + dy
                        guard nx >= 0, nx < context.width, ny >= 0, ny < context.height else { continue }
                        let nidx = ny * bytesPerRow + nx * 4
                        ptr[nidx] = r
                        ptr[nidx + 1] = g
                        ptr[nidx + 2] = b
                    }
                }
            }
        }
    }
    
    private func blurRegion(in context: CGContext, rect: CGRect, image: CGImage) {
        context.setFillColor(NSColor(white: 0, alpha: 0.7).cgColor)
        context.fill(rect)
    }
    
    private func eraseRegion(in context: CGContext, rect: CGRect, image: CGImage) {
        context.setFillColor(NSColor(white: 1, alpha: 1).cgColor)
        context.fill(rect)
    }
}

public enum RedactionError: Error, LocalizedError {
    case invalidImage
    case redactionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无效图像"
        case .redactionFailed(let message):
            return "打码失败: \(message)"
        }
    }
}
