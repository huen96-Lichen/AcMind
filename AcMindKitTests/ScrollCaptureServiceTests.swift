import CoreGraphics
import XCTest
@testable import AcMindKit

final class ScrollCaptureServiceTests: XCTestCase {
    func testDetectsFrozenTopHeader() throws {
        let previous = try makeScrollFrame(width: 160, height: 180, headerHeight: 28, bodyOffset: 0)
        let current = try makeScrollFrame(width: 160, height: 180, headerHeight: 28, bodyOffset: 24)

        let detectedHeight = ScrollCaptureService.detectedFrozenHeaderHeight(
            current: current,
            previous: previous,
            shiftPx: 24
        )

        XCTAssertGreaterThanOrEqual(detectedHeight, 26)
        XCTAssertLessThanOrEqual(detectedHeight, 30)
    }

    func testDoesNotDetectHeaderWhenTopChanges() throws {
        let previous = try makeScrollFrame(width: 160, height: 180, headerHeight: 0, bodyOffset: 0)
        let current = try makeScrollFrame(width: 160, height: 180, headerHeight: 0, bodyOffset: 24)

        let detectedHeight = ScrollCaptureService.detectedFrozenHeaderHeight(
            current: current,
            previous: previous,
            shiftPx: 24
        )

        XCTAssertEqual(detectedHeight, 0)
    }

    func testDoesNotTreatUnchangedFrameAsFrozenHeader() throws {
        let frame = try makeScrollFrame(width: 160, height: 180, headerHeight: 28, bodyOffset: 0)

        let detectedHeight = ScrollCaptureService.detectedFrozenHeaderHeight(
            current: frame,
            previous: frame,
            shiftPx: 24
        )

        XCTAssertEqual(detectedHeight, 0)
    }

    private func makeScrollFrame(
        width: Int,
        height: Int,
        headerHeight: Int,
        bodyOffset: Int
    ) throws -> CGImage {
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 255, count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<width {
                let index = y * bytesPerRow + x * 4
                let color: (UInt8, UInt8, UInt8)

                if y < headerHeight {
                    color = (24, 31, 42)
                } else {
                    let contentY = y + bodyOffset
                    color = (
                        UInt8((contentY * 7 + x * 3) % 251),
                        UInt8((contentY * 11 + x * 5 + 40) % 251),
                        UInt8((contentY * 13 + x * 2 + 80) % 251)
                    )
                }

                data[index] = color.0
                data[index + 1] = color.1
                data[index + 2] = color.2
                data[index + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(data) as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            throw XCTSkip("Failed to create test CGImage")
        }

        return image
    }
}
