import Foundation

actor ShellService {
    static let shared = ShellService()

    func runCommand(
        executable: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil
    ) async throws -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        if let cwd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }
        if let env = environment {
            var merged = ProcessInfo.processInfo.environment
            merged.merge(env) { _, new in new }
            process.environment = merged
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        return (output + errorOutput, process.terminationStatus)
    }

    func runShellCommand(
        _ command: String,
        workingDirectory: String? = nil
    ) async throws -> (output: String, exitCode: Int32) {
        try await runCommand(
            executable: "/bin/zsh",
            arguments: ["-c", command],
            workingDirectory: workingDirectory
        )
    }
}
