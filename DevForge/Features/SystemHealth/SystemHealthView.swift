import SwiftUI

struct SystemHealthView: View {
    @State private var snapshot: SystemSnapshot?
    @State private var history: [Double] = []
    @State private var topProcessesCPU: [ProcessInfoSample] = []
    @State private var topProcessesMemory: [ProcessInfoSample] = []

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if let snap = snapshot {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: Spacing.md) {
                        MetricCard(
                            title: "CPU",
                            value: String(format: "%.1f%%", snap.cpuUsage),
                            sparkline: history,
                            color: cpuColor(snap.cpuUsage)
                        )
                        MetricCard(
                            title: "Memory",
                            value: String(format: "%.1f GB", snap.memoryUsedGB),
                            sparkline: memoryHistory(),
                            color: memoryColor(snap.memoryUsedGB)
                        )
                        MetricCard(
                            title: "Disk I/O",
                            value: String(format: "R: %.1f MB/s", snap.diskReadMBs),
                            subtitle: String(format: "W: %.1f MB/s", snap.diskWriteMBs),
                            sparkline: [snap.diskReadMBs, snap.diskWriteMBs],
                            color: .blue
                        )
                        MetricCard(
                            title: "Network",
                            value: String(format: "↑ %.0f KB/s", snap.networkUpKBs),
                            subtitle: String(format: "↓ %.0f KB/s", snap.networkDownKBs),
                            sparkline: [snap.networkUpKBs, snap.networkDownKBs],
                            color: .green
                        )
                    }
                    .padding()

                    HStack(spacing: Spacing.md) {
                        thermalView(snap.thermalLevel)
                        memoryDetail(snap)
                    }
                    .padding(.horizontal)

                    HStack(spacing: Spacing.md) {
                        gpuView(snap)
                        fanView(snap)
                    }
                    .padding(.horizontal)

                    HStack(spacing: Spacing.md) {
                        processListView(title: "Top CPU", processes: topProcessesCPU, valueKey: \.cpuUsage, formatter: { "\($0)%" })
                        processListView(title: "Top Memory", processes: topProcessesMemory, valueKey: \.memoryBytes, formatter: { Int($0).bytesFormatted })
                    }
                    .padding(.horizontal)
                } else {
                    EmptyStateView(
                        icon: "gauge.with.dots.needle.33percent",
                        title: "Loading Metrics",
                        message: "Collecting system data..."
                    )
                }
            }
        }
        .task {
            let stream = await SystemMetricsService.shared.startPolling()
            for await snap in stream {
                snapshot = snap
                history.append(snap.cpuUsage)
                if history.count > 60 { history.removeFirst() }
                await loadTopProcesses()
            }
        }
    }

    private func cpuColor(_ usage: Double) -> Color {
        usage > 80 ? .red : usage > 50 ? .yellow : .green
    }

    private func memoryColor(_ used: Double) -> Color {
        used > 12 ? .red : used > 8 ? .yellow : .green
    }

    private func memoryHistory() -> [Double] {
        guard let snap = snapshot else { return [] }
        return [snap.memoryUsedGB]
    }

    private func thermalView(_ level: ThermalLevel) -> some View {
        HStack {
            Circle()
                .fill(thermalColor(level))
                .frame(width: 12, height: 12)
            Text("Thermal: \(level.rawValue)")
                .font(.appBody)
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(8)
    }

    private func thermalColor(_ level: ThermalLevel) -> Color {
        switch level {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }

    private func memoryDetail(_ snap: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Memory Detail").font(.appHeadline)
            Text("Used: \(String(format: "%.1f", snap.memoryUsedGB)) GB")
            Text("Wired: \(String(format: "%.1f", snap.memoryWiredGB)) GB")
            Text("Compressed: \(String(format: "%.1f", snap.memoryCompressedGB)) GB")
            Text("Free: \(String(format: "%.1f", snap.memoryFreeGB)) GB")
        }
        .font(.appCaption)
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(8)
    }

    private func gpuView(_ snap: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("GPU").font(.appHeadline)
            if let name = snap.gpuName {
                Text(name).font(.appBody)
            } else {
                Text("No GPU info").foregroundStyle(.secondary)
            }
            if let mem = snap.gpuMemoryGB {
                Text("Memory: \(String(format: "%.1f", mem)) GB").font(.appCaption)
            }
            Text("CPU Temp: \(snap.cpuTemperature >= 0 ? String(format: "%.1f°C", snap.cpuTemperature) : "N/A")")
                .font(.appCaption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSecondaryBackground)
        .cornerRadius(8)
    }

    private func fanView(_ snap: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Fans").font(.appHeadline)
            Text("Count: \(snap.fanCount)").font(.appBody)
            ForEach(Array(snap.fanSpeeds.enumerated()), id: \.offset) { i, speed in
                Text("Fan \(i): \(String(format: "%.0f", speed)) RPM")
                    .font(.appCaption)
            }
            if snap.fanSpeeds.isEmpty {
                Text("No fan data").foregroundStyle(.secondary).font(.appCaption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSecondaryBackground)
        .cornerRadius(8)
    }

    private func loadTopProcesses() async {
        let result = await SystemMetricsService.shared.readTopProcesses()
        topProcessesCPU = result.cpu
        topProcessesMemory = result.memory
    }

    private func processListView<T>(title: String, processes: [ProcessInfoSample], valueKey: KeyPath<ProcessInfoSample, T>, formatter: @escaping (T) -> String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.appHeadline)
            if processes.isEmpty {
                Text("No data").foregroundStyle(.secondary)
            } else {
                ForEach(processes.prefix(10)) { proc in
                    HStack {
                        Text(proc.name).font(.appCaption)
                        Spacer()
                        Text(formatter(proc[keyPath: valueKey]))
                            .font(.appMonospaceSmall)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.appSecondaryBackground)
        .cornerRadius(8)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    var subtitle: String?
    let sparkline: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).font(.appCaption).foregroundStyle(.secondary)
            Text(value).font(.appTitle.monospacedDigit())
                .foregroundStyle(color)
            if let subtitle {
                Text(subtitle).font(.appCaption).foregroundStyle(.secondary)
            }
            SparklineContainerView(data: sparkline, color: color)
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(8)
    }
}
