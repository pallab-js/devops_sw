import SwiftUI

struct CircularProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 5)
            Circle()
                .trim(from: 0.0, to: CGFloat(min(max(progress, 0.0), 1.0)))
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.8), color, color.opacity(0.8)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
        }
        .frame(width: 40, height: 40)
    }
}

struct SystemHealthView: View {
    @State private var snapshot: SystemSnapshot?
    @State private var cpuHistory: [Double] = []
    @State private var memoryHistoryData: [Double] = []
    @State private var diskReadHistory: [Double] = []
    @State private var diskWriteHistory: [Double] = []
    @State private var networkUpHistory: [Double] = []
    @State private var networkDownHistory: [Double] = []
    @State private var topProcessesCPU: [ProcessInfoSample] = []
    @State private var topProcessesMemory: [ProcessInfoSample] = []
    
    // Heartbeat pulse animation state
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.8

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // Header with live heartbeat polling indicator
                HStack {
                    Text("System Telemetry")
                        .font(.appTitle3.bold())
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.statusGreen)
                            .frame(width: 8, height: 8)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                    pulseScale = 1.5
                                    pulseOpacity = 0.2
                                }
                            }
                        Text("LIVE POLLING")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.statusGreen.opacity(0.08))
                    .cornerRadius(20)
                }
                .padding(.horizontal)
                .padding(.top, Spacing.sm)

                if let snap = snapshot {
                    // Core Metric Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: Spacing.md) {
                        let totalPhysicalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
                        let memoryProgress = snap.memoryUsedGB / totalPhysicalMemory

                        MetricCard(
                            title: "CPU",
                            value: String(format: "%.1f%%", snap.cpuUsage),
                            sparkline: cpuHistory,
                            color: cpuColor(snap.cpuUsage),
                            progress: snap.cpuUsage / 100.0
                        )
                        MetricCard(
                            title: "Memory",
                            value: String(format: "%.1f GB", snap.memoryUsedGB),
                            subtitle: String(format: "of %.0f GB Total", totalPhysicalMemory),
                            sparkline: memoryHistoryData,
                            color: memoryColor(snap.memoryUsedGB),
                            progress: memoryProgress
                        )
                        MetricCard(
                            title: "Disk I/O",
                            value: String(format: "R: %.1f MB/s", snap.diskReadMBs),
                            subtitle: String(format: "W: %.1f MB/s", snap.diskWriteMBs),
                            sparkline: diskReadHistory,
                            color: .blue
                        )
                        MetricCard(
                            title: "Network",
                            value: String(format: "\u{2191} %.0f KB/s", snap.networkUpKBs),
                            subtitle: String(format: "\u{2193} %.0f KB/s", snap.networkDownKBs),
                            sparkline: networkUpHistory,
                            color: .green
                        )
                    }
                    .padding(.horizontal)

                    // Hardware Silicon, acoustics and thermal stats
                    VStack(spacing: Spacing.md) {
                        HStack(spacing: Spacing.md) {
                            thermalView(snap.thermalLevel)
                            memoryDetail(snap)
                        }

                        HStack(spacing: Spacing.md) {
                            gpuView(snap)
                            fanView(snap)
                        }
                    }
                    .padding(.horizontal)

                    // Top consumers tabular list
                    HStack(spacing: Spacing.md) {
                        processListView(
                            title: "Top CPU Processes",
                            processes: topProcessesCPU,
                            valueKey: \.cpuUsage,
                            formatter: { String(format: "%.1f%%", $0) },
                            barProgress: { $0 / 100.0 },
                            color: .red
                        )
                        processListView(
                            title: "Top Memory Processes",
                            processes: topProcessesMemory,
                            valueKey: \.memoryBytes,
                            formatter: { Int($0).bytesFormatted },
                            barProgress: { Double($0) / Double(ProcessInfo.processInfo.physicalMemory) },
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, Spacing.lg)

                } else {
                    EmptyStateView(
                        icon: "gauge.with.dots.needle.33percent",
                        title: "Loading Telemetry",
                        message: "Collecting macOS kernel metrics..."
                    )
                    .padding(.top, 100)
                }
            }
        }
        .task {
            let stream = await SystemMetricsService.shared.startPolling()
            for await snap in stream {
                snapshot = snap
                appendHistory(&cpuHistory, snap.cpuUsage)
                appendHistory(&memoryHistoryData, snap.memoryUsedGB)
                appendHistory(&diskReadHistory, snap.diskReadMBs)
                appendHistory(&diskWriteHistory, snap.diskWriteMBs)
                appendHistory(&networkUpHistory, snap.networkUpKBs)
                appendHistory(&networkDownHistory, snap.networkDownKBs)
                await loadTopProcesses()
            }
        }
    }

    private func appendHistory(_ history: inout [Double], _ value: Double) {
        history.append(value)
        if history.count > 60 {
            history = Array(history.suffix(60))
        }
    }

    private func cpuColor(_ usage: Double) -> Color {
        usage > 85 ? .red : usage > 55 ? .yellow : .green
    }

    private func memoryColor(_ used: Double) -> Color {
        let totalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let ratio = used / totalGB
        return ratio > 0.85 ? .red : ratio > 0.60 ? .yellow : .green
    }

    private func thermalView(_ level: ThermalLevel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Thermal Pressure").font(.appHeadline)
                Spacer()
                Text(level.rawValue)
                    .font(.appSubheadline.bold())
                    .foregroundStyle(thermalColor(level))
            }
            Spacer()
            // Custom Segmented Gauge
            HStack(spacing: 4) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index <= thermalIndex(level) ? thermalColor(level) : Color.appSeparator)
                        .frame(height: 8)
                }
            }
        }
        .padding()
        .frame(height: 100)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func thermalIndex(_ level: ThermalLevel) -> Int {
        switch level {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        }
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Memory Allocation").font(.appHeadline)
            VStack(spacing: Spacing.xxxs) {
                memoryDetailRow(label: "Wired", value: snap.memoryWiredGB, color: .orange)
                memoryDetailRow(label: "Compressed", value: snap.memoryCompressedGB, color: .blue)
                memoryDetailRow(label: "Free Space", value: snap.memoryFreeGB, color: .green)
            }
        }
        .padding()
        .frame(height: 100)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func memoryDetailRow(label: String, value: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label).font(.appCaption).foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f GB", value)).font(.appCaption.bold())
        }
    }

    private func gpuView(_ snap: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Graphics / Metal").font(.appHeadline)
                Spacer()
                Image(systemName: "cpu.fill")
                    .foregroundStyle(.purple)
            }
            if let name = snap.gpuName {
                Text(name).font(.appBody.bold())
            } else {
                Text("Apple Silicon Integrated GPU").font(.appBody.bold())
            }

            if let mem = snap.gpuMemoryGB {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Active VRAM Allocation").font(.appCaption).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f GB", mem)).font(.appCaption.bold())
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: geo.size.width)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.purple)
                                    .frame(width: geo.size.width * CGFloat(min(mem / 16.0, 1.0))), // assumed 16GB max set
                                alignment: .leading
                            )
                    }
                    .frame(height: 4)
                }
            } else {
                Text("Unified System Memory Architecture").font(.appCaption).foregroundStyle(.secondary)
            }
            
            Text("CPU Temperature: \(snap.cpuTemperature >= 0 ? String(format: "%.1f\u{00B0}C", snap.cpuTemperature) : "N/A")")
                .font(.appCaption)
                .foregroundStyle(snap.cpuTemperature > 75 ? .red : snap.cpuTemperature > 55 ? .orange : .secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func fanView(_ snap: SystemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Thermal & Acoustics").font(.appHeadline)
                Spacer()
                Image(systemName: "wind")
                    .foregroundStyle(.blue)
            }
            Text("Active Fans: \(snap.fanCount)").font(.appSubheadline.bold())
            ForEach(Array(snap.fanSpeeds.enumerated()), id: \.offset) { i, speed in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Fan \(i)").font(.appCaption).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f RPM", speed)).font(.appCaption.bold())
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: geo.size.width)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.blue)
                                    .frame(width: geo.size.width * CGFloat(min(Double(speed) / 6000.0, 1.0))), // assumed 6000 RPM max
                                alignment: .leading
                            )
                    }
                    .frame(height: 4)
                }
            }
            if snap.fanSpeeds.isEmpty {
                Text("Passive cooling (0 RPM)").foregroundStyle(.secondary).font(.appCaption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func loadTopProcesses() async {
        let result = await SystemMetricsService.shared.readTopProcesses()
        topProcessesCPU = result.cpu
        topProcessesMemory = result.memory
    }

    private func processListView<T>(
        title: String,
        processes: [ProcessInfoSample],
        valueKey: KeyPath<ProcessInfoSample, T>,
        formatter: @escaping (T) -> String,
        barProgress: @escaping (T) -> Double,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(.appHeadline)
            if processes.isEmpty {
                Text("No data").foregroundStyle(.secondary)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(processes.prefix(7)) { proc in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(proc.name)
                                    .font(.appCaption.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text(formatter(proc[keyPath: valueKey]))
                                    .font(.appMonospaceSmall.bold())
                            }
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color.opacity(0.12))
                                    .frame(width: geo.size.width)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(color)
                                            .frame(width: geo.size.width * CGFloat(min(barProgress(proc[keyPath: valueKey]), 1.0))),
                                        alignment: .leading
                                    )
                            }
                            .frame(height: 4)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let sparkline: [Double]
    let color: Color
    var progress: Double? = nil

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.appCaption.bold()).foregroundStyle(.secondary)
                    Text(value).font(.appTitle3.monospacedDigit().bold())
                        .foregroundStyle(color)
                    if let subtitle {
                        Text(subtitle).font(.appCaption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let progress {
                    CircularProgressRing(progress: progress, color: color)
                }
            }
            Spacer(minLength: 4)
            SparklineContainerView(data: sparkline, color: color)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.25 : 0.1), radius: isHovered ? 8 : 4, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isHovered = hovering
            }
        }
    }
}
