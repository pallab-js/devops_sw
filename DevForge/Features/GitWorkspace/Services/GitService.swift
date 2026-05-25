import Foundation

actor GitService {
    static let shared = GitService()

    private func gitPath() -> String {
        let paths = ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return "/usr/bin/git"
    }

    private func runGitCommand(
        args: [String],
        workingDirectory: String
    ) async throws -> (output: String, exitCode: Int32) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: gitPath())
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { proc in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                continuation.resume(returning: (output + errorOutput, proc.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func getStatus(repoPath: String) async throws -> (branch: String?, files: [GitFileStatus]) {
        let branchResult = try await runGitCommand(args: ["branch", "--show-current"], workingDirectory: repoPath)
        let branch = branchResult.output.trimmed.nilIfEmpty

        let statusResult = try await runGitCommand(
            args: ["status", "--porcelain"],
            workingDirectory: repoPath
        )
        let files = statusResult.output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { line -> GitFileStatus in
                let code = String(line.prefix(2)).trimmed
                let path = String(line.dropFirst(3)).trimmed
                let type: GitStatusType
                switch code {
                case "M", " M": type = .modified
                case "A", " A": type = .added
                case "D", " D": type = .deleted
                case "R", " R": type = .renamed
                case "??": type = .untracked
                default: type = .modified
                }
                return GitFileStatus(path: path, statusCode: type)
            }
        return (branch, files)
    }

    func getLog(repoPath: String, limit: Int = 20) async throws -> [GitCommit] {
        let result = try await runGitCommand(
            args: ["log", "--oneline", "--format=%H|%an|%ai|%s", "-\(limit)"],
            workingDirectory: repoPath
        )
        return result.output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> GitCommit? in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 4 else { return nil }
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = dateFormatter.date(from: parts[2]) ?? Date()
                return GitCommit(
                    sha: parts[0],
                    message: parts[3],
                    author: parts[1],
                    date: date,
                    parentSHAs: []
                )
            }
    }

    func getBranches(repoPath: String) async throws -> [(name: String, isCurrent: Bool)] {
        let result = try await runGitCommand(
            args: ["branch", "--list"],
            workingDirectory: repoPath
        )
        return result.output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { line in
                let isCurrent = line.hasPrefix("*")
                let name = line.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "* "))
                return (name: name, isCurrent: isCurrent)
            }
    }

    func getDiff(repoPath: String, staged: Bool = false) async throws -> String {
        var args = ["diff"]
        if staged { args.append("--cached") }
        let result = try await runGitCommand(args: args, workingDirectory: repoPath)
        return result.output
    }

    func stage(files: [String], repoPath: String) async throws {
        var args = ["add", "--"]
        args.append(contentsOf: files)
        _ = try await runGitCommand(args: args, workingDirectory: repoPath)
    }

    func unstage(files: [String], repoPath: String) async throws {
        var args = ["reset", "HEAD", "--"]
        args.append(contentsOf: files)
        _ = try await runGitCommand(args: args, workingDirectory: repoPath)
    }

    func commit(repoPath: String, message: String, authorName: String? = nil, authorEmail: String? = nil) async throws {
        guard !message.trimmed.isEmpty else {
            throw AppError.git("Commit message cannot be empty")
        }
        var args = ["commit", "-m", message]
        if let name = authorName, let email = authorEmail {
            args.append("--author=\(name) <\(email)>")
        }
        _ = try await runGitCommand(args: args, workingDirectory: repoPath)
    }

    func checkout(branch: String, repoPath: String) async throws {
        _ = try await runGitCommand(args: ["checkout", branch], workingDirectory: repoPath)
    }

    func pull(repoPath: String) async throws -> String {
        let result = try await runGitCommand(args: ["pull"], workingDirectory: repoPath)
        return result.output
    }

    func push(repoPath: String) async throws -> String {
        let result = try await runGitCommand(args: ["push"], workingDirectory: repoPath)
        return result.output
    }

    func stashList(repoPath: String) async throws -> [(index: Int, message: String)] {
        let result = try await runGitCommand(
            args: ["stash", "list", "--format=%gd|%s"],
            workingDirectory: repoPath
        )
        return result.output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> (Int, String)? in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 2 else { return nil }
                let indexStr = parts[0].replacingOccurrences(of: "stash@{", with: "").replacingOccurrences(of: "}", with: "")
                guard let index = Int(indexStr) else { return nil }
                return (index, parts[1])
            }
    }

    func stashSave(repoPath: String, message: String = "") async throws {
        var args = ["stash", "push"]
        if !message.isEmpty { args.append(contentsOf: ["-m", message]) }
        _ = try await runGitCommand(args: args, workingDirectory: repoPath)
    }

    func stashPop(repoPath: String) async throws {
        _ = try await runGitCommand(args: ["stash", "pop"], workingDirectory: repoPath)
    }

    func stashDrop(repoPath: String, index: Int) async throws {
        _ = try await runGitCommand(args: ["stash", "drop", "stash@{\(index)}"], workingDirectory: repoPath)
    }

    func clone(url: String, destination: String) async throws -> String {
        let result = try await runGitCommand(args: ["clone", url, destination], workingDirectory: "/tmp")
        return result.output
    }
}
