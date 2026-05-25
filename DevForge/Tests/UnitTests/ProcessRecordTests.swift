import Testing
import Foundation
@testable import DevForge

struct ProcessRecordTests {
    @Test func testProcessRecordInitialization() {
        let record = ProcessRecord(
            name: "Test Server",
            command: "python3 -m http.server 8000",
            workingDirectory: "/tmp"
        )
        #expect(record.name == "Test Server")
        #expect(record.status == .idle)
        #expect(record.pid == nil)
    }

    @Test func testProcessStatusTransitions() {
        var record = ProcessRecord(name: "Test", command: "echo hello")
        #expect(record.status == .idle)

        record.setRunning(pid: 12345)
        #expect(record.status == .running)
        #expect(record.pid == 12345)
        #expect(record.lastStartedAt != nil)

        record.setStopped()
        #expect(record.status == .stopped)
        #expect(record.pid == nil)

        record.setFailed()
        #expect(record.status == .failed)
    }

    @Test func testProcessRecordEncoding() throws {
        let record = ProcessRecord(
            name: "Test",
            command: "echo hello",
            workingDirectory: "/tmp",
            pid: 100,
            status: .running
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(record)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProcessRecord.self, from: data)
        #expect(decoded.name == record.name)
        #expect(decoded.status == record.status)
        #expect(decoded.pid == record.pid)
    }
}
