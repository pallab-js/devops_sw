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
            onStop: { Task { await stopProcess(process) } },
            onDelete: { Task { await deleteProcess(process) } }
        )
    }

    private func loadProcesses() async {
        do {
            processes = try await AppDatabase.shared.read { db in
                try ProcessRecord.order(Column("createdAt").desc).fetchAll(db)
            }
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func saveProcess(_ record: ProcessRecord) async {
        do {
            try await AppDatabase.shared.write { db in
                try record.insert(db)
            }
            await loadProcesses()
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func startProcess(_ record: ProcessRecord) async {
        do {
            let updated = try await ProcessService.shared.spawn(record: record, database: AppDatabase.shared)
            if let idx = processes.firstIndex(where: { $0.id == updated.id }) {
                processes[idx] = updated
            }
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }

    private func stopProcess(_ record: ProcessRecord) async {
        await ProcessService.shared.terminate(recordID: record.id)
    }

    private func deleteProcess(_ record: ProcessRecord) async {
        await ProcessService.shared.terminate(recordID: record.id)
        do {
            try await AppDatabase.shared.write { db in
                try record.delete(db)
            }
            await loadProcesses()
            if selectedProcess?.id == record.id {
                selectedProcess = nil
            }
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }
}

struct ProcessRowView: View {
    let process: ProcessRecord

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(process.name)
                    .font(.appBody.bold())
                Text(process.command)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            statusBadge
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var statusBadge: some View {
        Text(process.status.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.12))
            .foregroundStyle(statusColor)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            )
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
    @State private var isRestarting = false

    var body: some View {
        VStack(spacing: 0) {
            infoSection
                .padding()
            Divider()
            actionBar
                .padding(.horizontal)
                .padding(.vertical, Spacing.xs)
            Divider()
            LogTailView(logLines: logLines, onClear: { logLines.removeAll() })
        }
        .task {
            guard let stream = await ProcessService.shared.observe(recordID: process.id) else { return }
            for await line in stream {
                logLines.append(line)
                if logLines.count > 10000 {
                    logLines.removeFirst(logLines.count - 5000)
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(process.name)
                    .font(.appTitle3.bold())
                Spacer()
                statusBadge(process.status)
            }
            .padding(.bottom, 2)
            
            VStack(spacing: Spacing.xxs) {
                detailRow(label: "Command", value: process.command)
                detailRow(label: "Working Directory", value: process.workingDirectory)
                detailRow(label: "PID", value: process.pid.map(String.init) ?? "\u{2014}")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.appCaption.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func statusBadge(_ status: ProcessStatus) -> some View {
        let color: Color = {
            switch status {
            case .running: return .statusGreen
            case .idle, .stopped: return .statusGray
            case .failed, .crashed: return .statusRed
            }
        }()
        
        return Text(status.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }

    private var actionBar: some View {
        HStack(spacing: Spacing.sm) {
            ActionButton(title: "Start", icon: "play.fill", color: .statusGreen, action: onStart)
                .disabled(process.status == .running)
            
            ActionButton(title: "Stop", icon: "stop.fill", color: .statusRed, action: onStop)
                .disabled(process.status != .running)
            
            ActionButton(title: "Restart", icon: "arrow.clockwise", color: .orange) {
                guard !isRestarting else { return }
                isRestarting = true
                Task {
                    await ProcessService.shared.terminate(recordID: process.id)
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await ProcessService.shared.waitForTermination(recordID: process.id)
                    onStart()
                    isRestarting = false
                }
            }
            .disabled(isRestarting || (process.status != .running && process.status != .stopped))
            
            Spacer()
            
            ActionButton(title: "Delete", icon: "trash", color: .red, role: .destructive, action: onDelete)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var role: ButtonRole? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.appCaption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isEnabled ? color.opacity(isHovered ? 0.25 : 0.12) : Color.gray.opacity(0.08))
            .foregroundStyle(isEnabled ? color : Color.secondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isEnabled ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered && isEnabled ? 1.03 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
