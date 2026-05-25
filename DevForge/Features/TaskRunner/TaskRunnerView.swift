import SwiftUI

struct TaskRunnerView: View {
    @State private var projectDir: URL?
    @State private var tasks: [DiscoveredTask] = []
    @State private var selectedTask: DiscoveredTask?
    @State private var outputLines: [TaskOutputLine] = []
    @State private var history: [TaskRun] = []
    @State private var isRunning = false
    @State private var currentTaskID: String?
    @State private var selectedTab = 0
    @State private var scheduleInterval = "300"
    @State private var isScheduled = false
    @State private var error: ErrorMessage?

    var body: some View {
        HSplitView {
            taskList
                .frame(minWidth: 220)
            if let task = selectedTask {
                taskDetail(task: task)
            } else {
                EmptyStateView(
                    icon: "play.circle.fill",
                    title: "Select a Task",
                    message: "Open a project directory to discover tasks."
                )
            }
        }
        .alert(item: $error) { err in
            Alert(title: Text("Error"), message: Text(err.message))
        }
    }

    private var taskList: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ActionButton(title: "Open Project", icon: "folder.badge.plus", color: .appAccent) {
                    selectProject()
                }
                if let projectDir {
                    Text(projectDir.path)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.top, Spacing.xxs)
                }
            }
            .padding()
            
            List(tasks, selection: $selectedTask) { task in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: taskSourceIcon(source: task.sourceFile))
                        .foregroundStyle(taskSourceColor(source: task.sourceFile))
                        .font(.title3)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(task.name)
                            .font(.appBody.bold())
                        Text(task.sourceFile)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, Spacing.xxs)
                .tag(task)
            }
            .listStyle(.inset)
        }
    }

    private func taskDetail(task: DiscoveredTask) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(task.name)
                        .font(.appTitle3.bold())
                    Text(task.command)
                        .font(.appMonospaceSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                
                ActionButton(
                    title: isRunning ? "Cancel" : "Run",
                    icon: isRunning ? "stop.fill" : "play.fill",
                    color: isRunning ? Color.statusRed : Color.statusGreen
                ) {
                    if isRunning {
                        if let id = currentTaskID {
                            Task { await TaskRunnerService.shared.cancel(taskID: id) }
                        }
                        isRunning = false
                        currentTaskID = nil
                    } else {
                        runTask(task)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .padding([.horizontal, .top])
            
            Picker("", selection: $selectedTab) {
                Text("Output").tag(0)
                Text("History").tag(1)
                Text("Schedule").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            TabView(selection: $selectedTab) {
                outputView.tag(0)
                historyView.tag(1)
                scheduleView.tag(2)
            }
            .tabViewStyle(.automatic)
            .padding(.horizontal)
        }
        .task(id: task.id) {
            await loadHistory(taskName: task.name)
        }
    }

    private var outputView: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow).frame(width: 8, height: 8)
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                }
                Spacer()
                Text("Console Terminal")
                    .font(.appMonospaceSmall.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    outputLines.removeAll()
                }
                .font(.appCaption)
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, Spacing.xs)
            .background(Color.black.opacity(0.95))
            
            Divider().background(Color.statusGray.opacity(0.3))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if outputLines.isEmpty {
                            Text("Console idle. Run task to see output.")
                                .font(.appMonospaceSmall)
                                .foregroundStyle(Color.statusGray)
                                .padding()
                        } else {
                            ForEach(outputLines) { line in
                                HStack(alignment: .top, spacing: Spacing.sm) {
                                    Text(line.timestamp.shortFormatted)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Color.logTimestamp)
                                        .frame(width: 65, alignment: .trailing)
                                    
                                    Text(line.content)
                                        .font(.appMonospaceSmall)
                                        .foregroundStyle(line.isError ? Color.logError : Color.statusGreen)
                                }
                                .id(line.id)
                            }
                        }
                    }
                    .padding(Spacing.xs)
                }
                .background(Color.black)
                .onChange(of: outputLines.count) { _, _ in
                    if let last = outputLines.last {
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
        .padding(.bottom, Spacing.sm)
    }

    private var scheduleView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Automated Scheduling")
                .font(.appHeadline)
                .foregroundStyle(.secondary)
            
            Form {
                TextField("Interval (seconds)", text: $scheduleInterval)
                    .textFieldStyle(.roundedBorder)
                    .font(.appBody)
            }
            .formStyle(.grouped)
            
            HStack {
                ActionButton(
                    title: isScheduled ? "Unschedule" : "Schedule",
                    icon: isScheduled ? "calendar.badge.minus" : "calendar.badge.plus",
                    color: isScheduled ? Color.statusRed : Color.statusGreen
                ) {
                    guard let task = selectedTask, let dir = projectDir,
                          let interval = Int(scheduleInterval), interval > 0 else { return }
                    Task {
                        if isScheduled {
                            try? await LaunchdService.shared.uninstall(taskName: task.name)
                            isScheduled = false
                        } else {
                            try? await LaunchdService.shared.install(
                                taskName: task.name,
                                command: task.command,
                                workingDirectory: dir.path,
                                intervalSeconds: interval
                            )
                            isScheduled = true
                        }
                    }
                }
                Spacer()
                if isScheduled {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                        Text("Scheduled every \(scheduleInterval)s")
                    }
                    .font(.appCaption.bold())
                    .foregroundStyle(Color.statusGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.statusGreen.opacity(0.12))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.statusGreen.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.bottom, Spacing.sm)
    }

    @ViewBuilder
    private var historyView: some View {
        if history.isEmpty {
            EmptyStateView(
                icon: "clock.arrow.circlepath",
                title: "No Runs Recorded",
                message: "Run logs will be saved here."
            )
            .frame(maxHeight: .infinity)
        } else {
            List(history) { run in
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(run.command)
                            .font(.appMonospaceSmall.bold())
                            .lineLimit(1)
                        Text(run.startTime.formatted)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    if let code = run.exitCode {
                        Text(code == 0 ? "SUCCESS" : "FAILED (\(code))")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background((code == 0 ? Color.statusGreen : Color.statusRed).opacity(0.12))
                            .foregroundStyle(code == 0 ? Color.statusGreen : Color.statusRed)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke((code == 0 ? Color.statusGreen : Color.statusRed).opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    if let duration = run.duration {
                        Text(Int(duration).durationFormatted)
                            .font(.appCaption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.appSecondaryBackground)
                            .cornerRadius(4)
                    }
                }
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, Spacing.sm)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func selectProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            projectDir = url
            Task { await discoverTasks(in: url) }
        }
    }

    private func discoverTasks(in url: URL) async {
        do {
            tasks = try await TaskDiscoveryService.shared.discoverTasks(in: url)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func runTask(_ task: DiscoveredTask) {
        guard let dir = projectDir else { return }
        outputLines = []
        isRunning = true
        let taskID = task.id.uuidString
        currentTaskID = taskID
        Task {
            let stream = await TaskRunnerService.shared.run(task: task, workingDirectory: dir.path)
            for await line in stream {
                outputLines.append(line)
            }
            isRunning = false
            currentTaskID = nil
            await loadHistory(taskName: task.name)
        }
    }

    private func loadHistory(taskName: String) async {
        do {
            history = try await TaskRunnerService.shared.getHistory(taskName: taskName)
        } catch {}
    }

    private func taskSourceIcon(source: String) -> String {
        if source.contains("package.json") {
            return "shippingbox.fill"
        } else if source.contains("Makefile") {
            return "hammer.fill"
        } else if source.contains("Justfile") {
            return "play.fill"
        }
        return "doc.text.fill"
    }

    private func taskSourceColor(source: String) -> Color {
        if source.contains("package.json") {
            return .green
        } else if source.contains("Makefile") {
            return .orange
        } else if source.contains("Justfile") {
            return .blue
        }
        return .gray
    }
}
