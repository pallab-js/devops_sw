import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func sendNotification(title: String, body: String, identifier: String = UUID().uuidString) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func notifyProcessCrashed(name: String) async {
        await sendNotification(
            title: "Process Crashed",
            body: "\(name) exited unexpectedly."
        )
    }

    func notifyTaskCompleted(name: String, exitCode: Int32) async {
        let status = exitCode == 0 ? "succeeded" : "failed (exit code \(exitCode))"
        await sendNotification(
            title: "Task \(status)",
            body: "Task '\(name)' \(status)."
        )
    }
}
