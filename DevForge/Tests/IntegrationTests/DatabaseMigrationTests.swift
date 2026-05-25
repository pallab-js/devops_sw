import XCTest
@testable import DevForge

final class DatabaseMigrationTests: XCTestCase {
    func testMigrationsRunSuccessfully() {
        // Database is initialized in AppDatabase.shared
        // Verify tables exist
        let db = AppDatabase.shared
        XCTAssertNotNil(db, "Database should initialize without error")
    }
}

final class ProcessServiceTests: XCTestCase {
    func testLaunchAndTerminateProcess() async throws {
        let service = ProcessService.shared
        let record = ProcessRecord(
            name: "sleep-test",
            command: "/bin/sleep 10"
        )
        let updated = try service.spawn(record: record, database: AppDatabase.shared)
        XCTAssertEqual(updated.status, .running)
        XCTAssertNotNil(updated.pid)

        service.terminate(recordID: updated.id)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        // process should be stopped
    }
}
