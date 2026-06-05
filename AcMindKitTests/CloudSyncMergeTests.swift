import XCTest
@testable import AcMindKit

final class CloudSyncMergeTests: XCTestCase {

    func testScheduledAgentTaskHasUpdatedAt() {
        let now = Date()
        let task = ScheduledAgentTask(
            name: "每日汇总",
            cronExpression: "0 9 * * *",
            skillName: "meeting-summary",
            inputParams: ["range": "yesterday"],
            updatedAt: now
        )

        XCTAssertEqual(task.updatedAt, now)
    }

    func testScheduledAgentTaskCoding() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_100_000)
        let lastRunAt = Date(timeIntervalSince1970: 1_700_050_000)

        let original = ScheduledAgentTask(
            id: "test-task-id-001",
            name: "周报生成",
            cronExpression: "0 18 * * 5",
            skillName: "weekly-report",
            inputParams: ["team": "engineering"],
            enabled: true,
            lastRunAt: lastRunAt,
            lastRunStatus: "success",
            lastRunTaskId: "run-001",
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScheduledAgentTask.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.cronExpression, original.cronExpression)
        XCTAssertEqual(decoded.skillName, original.skillName)
        XCTAssertEqual(decoded.inputParams, original.inputParams)
        XCTAssertEqual(decoded.enabled, original.enabled)
        XCTAssertEqual(decoded.lastRunStatus, original.lastRunStatus)
        XCTAssertEqual(decoded.lastRunTaskId, original.lastRunTaskId)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, original.createdAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(decoded.updatedAt.timeIntervalSince1970, original.updatedAt.timeIntervalSince1970, accuracy: 1)
    }
}
