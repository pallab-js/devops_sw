import SwiftUI
import GRDB

struct ProcessManagerView: View {
    @State private var processes: [ProcessRecord] = []
    @State private var selectedProcess: ProcessRecord?
    @State private var showNewProcessSheet = false
    @State private var error: ErrorMessage?

    var body: some View {
        HSplitView {
            processList
                .frame(minWidth: 280)
            if let selectedProcess {
                processDetail(process: selectedProcess)
            } else {
                EmptyStateView(
                    icon: "terminal.fill",
                    title: "No Process Selected",
                    message: "Select a process from the list or create a new one."
                )
            }
        }
        .task { await loadProcesses() }
        .sheet(isPresented: $showNewProcessSheet) {
            NewProcessSheet { record in
                Task { await saveProcess(record) }
            }
        }
        .alert(item: $error) { err in
            Alert(title: Text("Error"), message: Text(err.message))
        }
        .toolbar {
            ToolbarItem {
                Button(action: { showNewProcessSheet = true }) {
                    Label("New Process", systemImage: "plus")
                }
            }
        }
    }

    private var processList: some View {
        List(processes, selection: $selectedProcess) { process in
            ProcessRowView(process: process)
                .tag(process)
        }
        .listStyle(.inset)
    }

    private func processDetail(process: ProcessRecord) -> some View {
        ProcessDetailView(
            process: process,
            onStart: { Task { await startProcess(process) } },
            onStop: { stopProcess(process) },
            onDelete: { Task { await deleteProcess(process) } }
        )
    }

    private func loadProcesses() async {
        do {
            processes = try await AppDatabase.shared.read { db in
                try ProcessRecord.order(Column("createdAt").desc).fetchAll(db)
            }
        } catch {
            self.error = ErrorMessage(message: error.localizedDescription)
        }
    }

    private func saveProcess(_ record: ProcessRecord) async {
        do {
            try await AppDatabase.shared.write { db in
                try record.insert(db)
            }
            await loadProcesses()
        } catch {
            self.error = ErrorMessage(message: error.localizedDescription)
        }
    }

    private func startProcess(_ record: ProcessRecord) async {
        do {
            let updated = try await ProcessService.shared.spawn(record: record, database: AppDatabase.shared)
            if let idx = processes.firstIndex(where: { $0.id == updated.id }) {
                processes[idx] = updated
            }
        } catch {
            self.error = ErrorMessage(message: error.localizedDescription)
        }
    }

    private func stopProcess(_ record: ProcessRecord) {
        ProcessService.shared.terminate(recordID: record.id)
    }

    private func deleteProcess(_ record: ProcessRecord) async {
        do {
            stopProcess(record)
            try await AppDatabase.shared.write { db in
                try record.delete(db)
            }
            await loadProcesses()
            if selectedProcess?.id == record.id {
                selectedProcess = nil
            }
        } catch {
            self.error = ErrorMessage(message: error.localizedDescription)
        }
    }
}

struct ProcessRowView: View {
    let process: ProcessRecord

    var body: some View {
        HStack(spacing: Spacing.sm) {
            statusDot
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(process.name)
                    .font(.appBody)
                Text(process.command)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch process.status {
        case .running: .statusGreen
        case .idle: .statusGray
        case .stopped: .statusGray
        case .failed, .crashed: .statusRed
        }
    }
}

struct ProcessDetailView: View {
    let process: ProcessRecord
    let onStart: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void

    @State private var logLines: [LogLine] = []

    var body: some View {
        VStack(spacing: 0) {
            infoSection
                .padding()
            Divider()
            actionBar
                .padding(.horizontal)
                .padding(.vertical, Spacing.xs)
            Divider()
            LogTailView(logLines: logLines)
        }
        .task {
            guard let stream = ProcessService.shared.observe(recordID: process.id) else { return }
            for await line in stream {
                logLines.append(line)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(process.name)
                .font(.appHeadline)
            LabeledContent("Command", value: process.command)
            LabeledContent("Working Dir", value: process.workingDirectory)
            LabeledContent("PID", value: process.pid.map(String.init) ?? "—")
            LabeledContent("Status", value: process.status.rawValue.capitalized)
        }
    }

    private var actionBar: some View {
        HStack(spacing: Spacing.sm) {
            Button("Start", action: onStart)
                .disabled(process.status == .running)
            Button("Stop", action: onStop)
                .disabled(process.status != .running)
            Button("Restart") {
                onStop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onStart() }
            }
            .disabled(process.status != .running && process.status != .stopped)
            Spacer()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
