import XCTest
@testable import AcMindKit

final class GPUStatusReaderTests: XCTestCase {
    func testGPUUsageUnavailableReasonIsReportedOnAppleSiliconWhenUsageSourceIsMissing() {
        let reason = GPUStatusReader.gpuUsageUnavailableReason(isAppleSilicon: true, gpuUsage: nil)

        XCTAssertEqual(reason?.id, "gpu-usage-unavailable")
        XCTAssertEqual(reason?.category, "gpu")
        XCTAssertEqual(reason?.message, "GPU 使用率不可用")
        XCTAssertEqual(reason?.detail, "Apple Silicon GPU usage source unavailable")
    }

    func testGPUUsageUnavailableReasonIsOmittedWhenUsageIsAvailableOrHardwareIsNotAppleSilicon() {
        XCTAssertNil(GPUStatusReader.gpuUsageUnavailableReason(isAppleSilicon: true, gpuUsage: 37.5))
        XCTAssertNil(GPUStatusReader.gpuUsageUnavailableReason(isAppleSilicon: false, gpuUsage: nil))
    }

    func testGPUReaderMarksUnsupportedHardwareClassesWithAnExplicitReason() async {
        let reader = GPUStatusReader()
        let partial = await reader.read()

        XCTAssertTrue(
            partial.unavailableReasons.contains(where: {
                $0.id == "gpu-usage-unavailable" || $0.id == "gpu-usage-unsupported"
            })
        )
    }
}
