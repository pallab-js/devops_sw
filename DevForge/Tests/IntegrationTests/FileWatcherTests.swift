import XCTest
@testable import DevForge

final class FileWatcherTests: XCTestCase {
    func testFileWatcherDetectsWrites() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("devforge-test-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: tempFile.path, contents: nil)

        defer { try? FileManager.default.removeItem(at: tempFile) }

        let watcher = FileWatcherService.shared
        let stream = await watcher.watch(url: tempFile)

        // Write to the file
        try "test data".write(to: tempFile, atomically: true, encoding: .utf8)

        let expectation = XCTestExpectation(description: "File change detected")
        Task {
            for await _ in stream {
                expectation.fulfill()
                break
            }
        }
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}
