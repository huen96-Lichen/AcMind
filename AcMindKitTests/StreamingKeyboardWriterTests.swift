import XCTest
@testable import AcMindKit

final class StreamingKeyboardWriterTests: XCTestCase {

    func testChunkMerging() async throws {
        let writer = StreamingKeyboardWriter()
        await writer.write(chunk: "你")
        await writer.write(chunk: "好")
        await writer.write(chunk: "世")
        await writer.write(chunk: "界")
        try await Task.sleep(nanoseconds: 20_000_000)
        await writer.finish()
    }

    func testFinishFlushesRemaining() async throws {
        let writer = StreamingKeyboardWriter()
        await writer.write(chunk: "hello")
        await writer.finish()
    }

    func testCancelClearsBuffer() async throws {
        let writer = StreamingKeyboardWriter()
        await writer.write(chunk: "test")
        await writer.cancel()
        await writer.finish()
    }

    func testCancelThenWriteIsNoOp() async throws {
        let writer = StreamingKeyboardWriter()
        await writer.write(chunk: "before")
        await writer.cancel()
        await writer.write(chunk: "after")
        await writer.finish()
    }

    func testEmptyChunkIgnored() async throws {
        let writer = StreamingKeyboardWriter()
        await writer.write(chunk: "")
        await writer.write(chunk: "real")
        await writer.write(chunk: "")
        try await Task.sleep(nanoseconds: 20_000_000)
        await writer.finish()
    }

    func testLargeChunk() async throws {
        let writer = StreamingKeyboardWriter()
        let large = String(repeating: "A", count: 500)
        await writer.write(chunk: large)
        await writer.finish()
    }

    func testFinishOnEmptyBufferIsNoOp() async throws {
        let writer = StreamingKeyboardWriter()
        await writer.finish()
    }

    func testRapidSmallChunks() async throws {
        let writer = StreamingKeyboardWriter()
        for char in "这是一个快速连续写入的测试" {
            await writer.write(chunk: String(char))
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        await writer.finish()
    }

    func testWriteAfterFinish() async throws {
        let writer = StreamingKeyboardWriter()
        await writer.write(chunk: "first")
        await writer.finish()
        await writer.write(chunk: "second")
        await writer.finish()
    }
}
