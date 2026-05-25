import SwiftUI

struct LogAggregatorView: View {
    @State private var watchedFiles: [URL] = []
    @State private var logLines: [LogLine] = []
    @State private var filterText = ""
    @State private var showErrorsOnly = false
    @State private var isPaused = false
    @State private var pendingLines: [LogLine] = []

    private var filteredLines: [LogLine] {
        var lines = isPaused ? pendingLines : logLines
        if showErrorsOnly { lines = lines.filter { $0.isError } }
        if !filterText.isEmpty {
            lines = lines.filter { $0.content.localizedCaseInsensitiveContains(filterText) }
        }
        return lines
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal)
                .padding(.vertical, Spacing.xxs)
            Divider()
            logView
        }
        .task { await addQuickLogs() }
    }

    private var toolbar: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Filter (regex)...", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 250)
            Toggle("Errors only", isOn: $showErrorsOnly)
                .toggleStyle(.checkbox)
                .controlSize(.small)
            Spacer()
            Button("Add File") { addFile() }
            Menu("Quick Add") {
                Button("/var/log/system.log") { addSystemLog(path: "/var/log/system.log") }
                Button("~/Library/Logs") { addSystemLog(path: NSHomeDirectory() + "/Library/Logs") }
            }
            Button(isPaused ? "Resume" : "Pause") { isPaused.toggle() }
            Button("Clear") { logLines.removeAll(); pendingLines.removeAll() }
            Button("Export") { exportLogs() }
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredLines) { line in
                        HStack(alignment: .top, spacing: Spacing.xxs) {
                            Text(line.timestamp.shortFormatted)
                                .foregroundStyle(Color.logTimestamp)
                                .frame(width: 60, alignment: .trailing)
                            Text(line.source)
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text(line.content)
                                .foregroundStyle(lineStyle(line))
                                .textSelection(.enabled)
                        }
                        .font(.appMonospaceSmall)
                        .id(line.id)
                    }
                }
                .padding(Spacing.xs)
            }
            .onChange(of: logLines.count) { _, _ in
                if !isPaused, let last = filteredLines.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .background(.black, in: Rectangle())
    }

    private func lineStyle(_ line: LogLine) -> Color {
        if line.isError { return .logError }
        return .logInfo
    }

    private func addFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            watchedFiles.append(url)
            Task { await tailFile(url: url) }
        }
    }

    private func addSystemLog(path: String) {
        let url = URL(fileURLWithPath: path)
        guard !watchedFiles.contains(url) else { return }
        watchedFiles.append(url)
        Task { await tailFile(url: url) }
    }

    private func tailFile(url: URL) async {
        let stream = await LogTailService.shared.tail(file: url)
        for await line in stream {
            if isPaused {
                pendingLines.append(line)
            } else {
                logLines.append(line)
            }
        }
    }

    private func addQuickLogs() async {
        // add default log locations
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "devforge-logs.txt"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            let text = logLines.map { "\($0.timestamp.shortFormatted) [\($0.source)] \($0.content)" }
                .joined(separator: "\n")
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
