import SwiftUI

struct LogAggregatorView: View {
    @State private var watchedFiles: [URL] = []
    @State private var logLines: [LogLine] = []
    @State private var filterText = ""
    @State private var showErrorsOnly = false
    @State private var isPaused = false
    @State private var pendingLines: [LogLine] = []

    private var displayLines: [LogLine] {
        logLines.suffix(10000)
    }

    private var filteredLines: [LogLine] {
        var lines = isPaused ? pendingLines : displayLines
        if showErrorsOnly { lines = lines.filter { $0.isError } }
        if !filterText.isEmpty {
            lines = lines.filter { $0.content.localizedCaseInsensitiveContains(filterText) }
        }
        return lines
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .padding()
            
            logView
                .padding(.horizontal)
                .padding(.bottom)
        }
        .task { await addQuickLogs() }
    }

    private var toolbar: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Filter...", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
            
            Toggle("Errors Only", isOn: $showErrorsOnly)
                .toggleStyle(.checkbox)
                .controlSize(.small)
            
            Spacer()
            
            HStack(spacing: Spacing.xs) {
                ActionButton(title: "Add File", icon: "doc.badge.plus", color: .appAccent) {
                    addFile()
                }
                
                Menu("Quick Add") {
                    Button("/var/log/system.log") { addSystemLog(path: "/var/log/system.log") }
                    Button("~/Library/Logs") { addSystemLog(path: NSHomeDirectory() + "/Library/Logs") }
                }
                
                ActionButton(
                    title: isPaused ? "Resume" : "Pause",
                    icon: isPaused ? "play.fill" : "pause.fill",
                    color: isPaused ? Color.statusGreen : Color.statusYellow
                ) {
                    if isPaused {
                        logLines.append(contentsOf: pendingLines)
                        pendingLines.removeAll()
                    }
                    isPaused.toggle()
                }
                
                ActionButton(title: "Clear", icon: "trash", color: .statusRed) {
                    logLines.removeAll()
                    pendingLines.removeAll()
                }
                
                ActionButton(title: "Export", icon: "square.and.arrow.up", color: .blue) {
                    exportLogs()
                }
            }
        }
    }

    private var logView: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow).frame(width: 8, height: 8)
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                }
                Spacer()
                Text("Log Stream Terminal")
                    .font(.appMonospaceSmall.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if isPaused {
                    Text("PAUSED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.statusYellow)
                } else {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.statusGreen)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, Spacing.xs)
            .background(Color.black.opacity(0.95))
            
            Divider().background(Color.statusGray.opacity(0.3))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredLines) { line in
                            LogLineRowView(
                                line: line,
                                severity: logSeverity(content: line.content, isError: line.isError),
                                contentColor: lineStyle(line)
                            )
                            .id(line.id)
                        }
                    }
                    .padding(Spacing.xs)
                }
                .background(Color.black)
                .onChange(of: logLines.count) { _, _ in
                    if !isPaused, let last = filteredLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.statusGray.opacity(0.5), lineWidth: 1)
        )
    }

    private func lineStyle(_ line: LogLine) -> Color {
        if line.isError { return Color.logError }
        return Color.logInfo
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

    enum LogSeverity: String {
        case error = "ERROR"
        case warning = "WARN"
        case info = "INFO"
        case debug = "DEBUG"
    }

    private func logSeverity(content: String, isError: Bool) -> LogSeverity {
        if isError { return .error }
        let upper = content.uppercased()
        if upper.contains("ERROR") || upper.contains("CRITICAL") || upper.contains("FATAL") {
            return .error
        } else if upper.contains("WARN") || upper.contains("WARNING") {
            return .warning
        } else if upper.contains("DEBUG") || upper.contains("TRACE") {
            return .debug
        } else {
            return .info
        }
    }
}

struct SeverityBadge: View {
    let severity: LogAggregatorView.LogSeverity
    
    var body: some View {
        let color: Color = {
            switch severity {
            case .error: return Color.statusRed
            case .warning: return Color.statusYellow
            case .info: return Color.appAccent
            case .debug: return Color.statusGray
            }
        }()
        
        return Text(severity.rawValue)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .frame(width: 48)
    }
}

struct LogLineRowView: View {
    let line: LogLine
    let severity: LogAggregatorView.LogSeverity
    let contentColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Text(line.timestamp.shortFormatted)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.logTimestamp)
                .frame(width: 65, alignment: .trailing)
            
            SeverityBadge(severity: severity)
            
            Text(line.source)
                .font(.appMonospaceSmall)
                .foregroundStyle(Color.secondary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
            
            Text(line.content)
                .font(.appMonospaceSmall)
                .foregroundStyle(contentColor)
                .textSelection(.enabled)
        }
    }
}
