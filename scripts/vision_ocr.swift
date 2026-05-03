#!/usr/bin/env swift

// vision_ocr.swift — macOS Vision Framework OCR CLI
// Usage: swift vision_ocr.swift <image_path> [language]
//
// Extracts text from an image using Apple's Vision Framework.
// Outputs recognized text to stdout.
// Errors are printed to stderr.

import Foundation
import Vision
import AppKit

let args = CommandLine.arguments

guard args.count >= 2 else {
    fputs("Error: Usage: swift vision_ocr.swift <image_path> [language]\n", stderr)
    exit(1)
}

let imagePath = args[1]
let language = args.count >= 3 ? args[2] : nil

// Load image
guard FileManager.default.fileExists(atPath: imagePath) else {
    fputs("Error: Image file not found: \(imagePath)\n", stderr)
    exit(1)
}

guard let image = NSImage(contentsOfFile: imagePath) else {
    fputs("Error: Failed to load image: \(imagePath)\n", stderr)
    exit(1)
}

guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Error: Failed to get CGImage from NSImage\n", stderr)
    exit(1)
}

// Create text recognition request
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

if let lang = language {
    request.recognitionLanguages = [lang]
} else {
    // Default: Chinese + English
    request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
}

// Perform recognition
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

do {
    try handler.perform([request])
} catch {
    fputs("Error: Text recognition failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}

guard let observations = request.results else {
    // No text found — output empty string (not an error)
    print("")
    exit(0)
}

// Extract text from observations
let recognizedStrings = observations.compactMap { observation -> String? in
    guard let candidate = observation.topCandidates(1).first else { return nil }
    return candidate.string
}

if recognizedStrings.isEmpty {
    print("")
    exit(0)
}

// Join with newlines
let result = recognizedStrings.joined(separator: "\n")
print(result)
