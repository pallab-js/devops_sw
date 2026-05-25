import SwiftUI

struct TaskRunnerView: View {
    @State private var projectDir: URL?
    @State private var tasks: [DiscoveredTask] = []
    @State private var selectedTask: DiscoveredTask?
    @State private var outputLines: [TaskOutputLine] = []
    @State private var history: [TaskRun] = []
    @State private var isRunning = false
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
            HStack {
                Button("Open Project") { selectProject() }
                Spacer()
            }
            .padding()
            List(tasks, selection: $selectedTask) { task in
                VStack(alignment: .leading) {
                    Text(task.name).font(.appBody)
                    Text(task.sourceFile).font(.appCaption).foregroundStyle(.secondary)
                }
                .tag(task)
            }
            .listStyle(.inset)
        }
    }

    private func taskDetail(task: DiscoveredTask) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(task.name).font(.appHeadline)
                Spacer()
                Button(isRunning ? "Cancel" : "Run") {
                    if isRunning { TaskRunnerService.shared.cancel(); isRunning = false }
                    else { runTask(task) }
                }
            }
            .padding()
            Picker("", selection: $selectedTab) {
                Text("Output").tag(0)
                Text("History").tag(1)
                Text("Schedule").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            TabView(selection: $selectedTab) {
                outputView.tag(0)
                historyView.tag(1)
                scheduleView.tag(2)
            }
            .tabViewStyle(.automatic)
        }
    }

    private var outputView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(outputLines) { line in
                        HStack {
                            Text(line.timestamp.shortFormatted)
                                .foregroundStyle(Color.logTimestamp)
                                .frame(width: 60, alignment: .trailing)
                            Text(line.content)
                                .foregroundStyle(line.isError ? Color.logError : .primary)
                        }
                        .font(.appMonospaceSmall)
                        .id(line.id)
                    }
                }
                .padding(Spacing.xs)
            }
            .onChange(of: outputLines.count) { _, _ in
                if let last = outputLines.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
        .background(.black, in: Rectangle())
    }

    private var scheduleView: some View {
        Form {
            TextField("Interval (seconds)", text: $scheduleInterval)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(isScheduled ? "Unschedule" : "Schedule") {
                    guard let task = selectedTask, let dir = projectDir,
                          let interval = Int(scheduleInterval), interval > 0 else { return }
                    Task {
                        if isScheduled {
                            try? await LaunchdService.shared.uninstall(taskName: task.name)
                            isScheduled = false
                        } else {
                            try? LaunchdService.shared.install(
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
                    Text("Scheduled every \(scheduleInterval)s").foregroundStyle(Color.statusGreen)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var historyView: some View {
        List(history) { run in
            HStack {
                VStack(alignment: .leading) {
                    Text(run.command).font(.appMonospaceSmall)
                    Text(run.startTime.formatted).font(.appCaption).foregroundStyle(.secondary)
                }
                Spacer()
                if let code = run.exitCode {
                    Text(code == 0 ? "✓" : "✗ \(code)")
                        .foregroundStyle(code == 0 ? Color.statusGreen : Color.statusRed)
                }
                if let duration = run.duration {
                    Text(Int(duration).durationFormatted).font(.appCaption)
                }
            }
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
        let stream = TaskRunnerService.shared.run(task: task, workingDirectory: dir.path)
        Task {
            for await line in stream {
                outputLines.append(line)
            }
            isRunning = false
            await loadHistory(taskName: task.name)
        }
    }

    private func loadHistory(taskName: String) async {
        do {
            history = try await TaskRunnerService.shared.getHistory(taskName: taskName)
        } catch {}
    }
}
