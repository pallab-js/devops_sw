import Foundation

actor LaunchdService {
    static let shared = LaunchdService()

    private var launchAgentsDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents")
    }

    private func plistURL(taskName: String) -> URL {
        launchAgentsDir.appendingPathComponent("com.devforge.task.\(taskName).plist")
    }

    func generatePlist(
        taskName: String,
        command: String,
        workingDirectory: String,
        intervalSeconds: Int
    ) -> String {
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.devforge.task.\(taskName)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/zsh</string>
                <string>-c</string>
                <string>\(escapedCommand)</string>
            </array>
            <key>WorkingDirectory</key>
            <string>\(workingDirectory)</string>
            <key>StartInterval</key>
            <integer>\(intervalSeconds)</integer>
            <key>RunAtLoad</key>
            <false/>
            <key>StandardOutPath</key>
            <string>/tmp/com.devforge.\(taskName).stdout</string>
            <key>StandardErrorPath</key>
            <string>/tmp/com.devforge.\(taskName).stderr</string>
        </dict>
        </plist>
        """
    }

    func install(taskName: String, command: String, workingDirectory: String, intervalSeconds: Int) throws {
        let plist = generatePlist(
            taskName: taskName,
            command: command,
            workingDirectory: workingDirectory,
            intervalSeconds: intervalSeconds
        )
        let url = plistURL(taskName: taskName)
        try plist.write(to: url, atomically: true, encoding: .utf8)
        let output = try runLaunchctl(["bootstrap", "gui/\(getuid())", url.path])
        if output.contains("error") || output.contains("failed") {
            throw AppError.unknown(NSError(domain: "LaunchdService", code: -1, userInfo: [NSLocalizedDescriptionKey: output]))
        }
    }

    func uninstall(taskName: String) throws {
        let url = plistURL(taskName: taskName)
        _ = try runLaunchctl(["bootout", "gui/\(getuid())", url.path])
        try? FileManager.default.removeItem(at: url)
    }

    func isLoaded(taskName: String) -> Bool {
        guard let output = try? runLaunchctl(["list"]) else { return false }
        return output.contains("com.devforge.task.\(taskName)")
    }

    func listManagedAgents() throws -> [(name: String, isLoaded: Bool)] {
        let listOutput = (try? runLaunchctl(["list"])) ?? ""
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: launchAgentsDir,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return items
            .filter { $0.lastPathComponent.hasPrefix("com.devforge.") && $0.pathExtension == "plist" }
            .map { url in
                let name = url.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "com.devforge.task.", with: "")
                let loaded = listOutput.contains("com.devforge.task.\(name)")
                return (name, loaded)
            }
    }

    private func runLaunchctl(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        return output + error
    }
}
