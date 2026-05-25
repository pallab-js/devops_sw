import Foundation

actor SystemMetricsService {
    static let shared = SystemMetricsService()

    private var history: [SystemSnapshot] = []
    private var previousNetwork: (up: Int64, down: Int64)?
    private var previousDisk: (read: Int64, write: Int64)?

    func startPolling() -> AsyncStream<SystemSnapshot> {
        let (stream, continuation) = AsyncStream<SystemSnapshot>.makeStream()
        Task {
            while true {
                let snapshot = await captureSnapshot()
                continuation.yield(snapshot)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        return stream
    }

    func captureSnapshot() async -> SystemSnapshot {
        let cpu = readCPU()
        let memory = readMemory()
        let disk = readDiskIO()
        let network = readNetwork()
        let gpu = await readGPU()
        let fans = await readFanSpeeds()
        return SystemSnapshot(
            cpuUsage: cpu.overall,
            cpuPerCore: cpu.perCore,
            memoryUsedGB: memory.usedGB,
            memoryWiredGB: memory.wiredGB,
            memoryCompressedGB: memory.compressedGB,
            memoryFreeGB: memory.freeGB,
            diskReadMBs: disk.readMBs,
            diskWriteMBs: disk.writeMBs,
            networkUpKBs: network.upKBs,
            networkDownKBs: network.downKBs,
            thermalLevel: readThermal(),
            gpuName: gpu.name,
            gpuMemoryGB: gpu.memoryGB,
            fanCount: fans.count,
            fanSpeeds: fans.speeds,
            cpuTemperature: fans.cpuTemp,
            timestamp: Date()
        )
    }

    private func readGPU() async -> (name: String?, memoryGB: Double?) {
        let info = await GPUMetricsService.shared.getGPUInfo()
        return (info?.name, info?.recommendedMaxGB)
    }

    private func readFanSpeeds() async -> (count: Int, speeds: [Float], cpuTemp: Float) {
        let fans = FanSpeedService.shared
        let count = await fans.getFanCount()
        let speeds = await fans.getAllFanSpeeds().map { $0.speedRPM }
        let cpuTemp = await fans.getCPUTemperature()
        return (count, speeds, cpuTemp)
    }

    private func readCPU() -> (overall: Double, perCore: [Double]) {
        let host = mach_host_self()
        var count = natural_t(0)
        var cpuInfo: processor_info_array_t?
        var numCpuInfo = mach_msg_type_number_t(0)

        let result = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &count,
            &cpuInfo,
            &numCpuInfo
        )
        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return (0, [])
        }

        let data = Array(UnsafeBufferPointer(
            start: info,
            count: Int(numCpuInfo)
        ))
        var perCore: [Double] = []
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0

        for i in 0..<Int(count) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = UInt64(data[offset + Int(CPU_STATE_USER)])
            let system = UInt64(data[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(data[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(data[offset + Int(CPU_STATE_NICE)])

            totalUser += user
            totalSystem += system
            totalIdle += idle

            let total = user + system + idle + nice
            if total > 0 {
                perCore.append(Double(user + system) / Double(total) * 100)
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCpuInfo * 4))
        let overall = perCore.reduce(0, +) / max(Double(perCore.count), 1)
        return (overall, perCore)
    }

    private func readMemory() -> (usedGB: Double, wiredGB: Double, compressedGB: Double, freeGB: Double) {
        let host = mach_host_self()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { ptr in
                host_statistics64(host, HOST_VM_INFO64, ptr, &size)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0, 0, 0) }

        let pageSize = UInt64(vm_page_size)
        let used = UInt64(vmStats.active_count + vmStats.wire_count)
        let wired = UInt64(vmStats.wire_count)
        let compressed = UInt64(vmStats.compressor_page_count)
        let free = UInt64(vmStats.free_count)

        return (
            Double(used * pageSize) / 1_073_741_824,
            Double(wired * pageSize) / 1_073_741_824,
            Double(compressed * pageSize) / 1_073_741_824,
            Double(free * pageSize) / 1_073_741_824
        )
    }

    private func readDiskIO() -> (readMBs: Double, writeMBs: Double) {
        let previous = previousDisk ?? (0, 0)

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)

        var totalRead: Int64 = 0
        var totalWrite: Int64 = 0

        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let props = IORegistryEntryCreateCFProperty(
                service, "Statistics" as CFString, kCFAllocatorDefault, 0
            ) {
                if let dict = props.takeRetainedValue() as? [String: Any] {
                    totalRead += dict["Bytes (Read)"] as? Int64 ?? 0
                    totalWrite += dict["Bytes (Write)"] as? Int64 ?? 0
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)

        let readDelta = totalRead - previous.read
        let writeDelta = totalWrite - previous.write
        previousDisk = (totalRead, totalWrite)

        return (Double(readDelta) / 2_000_000, Double(writeDelta) / 2_000_000)
    }

    private func readNetwork() -> (upKBs: Double, downKBs: Double) {
        let previous = previousNetwork ?? (0, 0)

        var ifList: UnsafeMutablePointer<ifaddrs>?
        getifaddrs(&ifList)
        guard let first = ifList else { return (0, 0) }

        var totalUp: Int64 = 0
        var totalDown: Int64 = 0

        var cursor = first
        while true {
            let addr = cursor.pointee.ifa_addr.pointee
            if addr.sa_family == UInt8(AF_LINK) {
                let data = cursor.pointee.ifa_data?.assumingMemoryBound(to: if_data.self).pointee
                if let data {
                    totalDown += Int64(data.ifi_ibytes)
                    totalUp += Int64(data.ifi_obytes)
                }
            }
            guard let next = cursor.pointee.ifa_next else { break }
            cursor = next
        }
        freeifaddrs(ifList)

        let upDelta = totalUp - previous.up
        let downDelta = totalDown - previous.down
        previousNetwork = (totalUp, totalDown)

        return (Double(upDelta) / 2000, Double(downDelta) / 2000)
    }

    func readTopProcesses() -> (cpu: [ProcessInfoSample], memory: [ProcessInfoSample]) {
        var cpuSamples: [ProcessInfoSample] = []
        var memorySamples: [ProcessInfoSample] = []

        let bufferSize = proc_listpids(UInt32(bitPattern: PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return ([], []) }

        var pids = [pid_t](repeating: 0, count: Int(bufferSize))
        let _ = proc_listpids(UInt32(bitPattern: PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.size * pids.count))

        for pid in pids where pid > 0 {
            var info = proc_taskinfo()
            let size = proc_pidinfo(pid, Int32(PROC_PIDTASKINFO), 0, &info, Int32(MemoryLayout<proc_taskinfo>.size))
            guard size > 0 else { continue }

            var nameBuffer = [CChar](repeating: 0, count: 1024)
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = String(cString: nameBuffer)
            guard !name.isEmpty else { continue }

            let cpuUsage = Double(info.pti_total_user + info.pti_total_system) / 1_000_000
            let memoryBytes = info.pti_resident_size

            cpuSamples.append(ProcessInfoSample(pid: pid, name: name, cpuUsage: cpuUsage, memoryBytes: memoryBytes))
            memorySamples.append(ProcessInfoSample(pid: pid, name: name, cpuUsage: cpuUsage, memoryBytes: memoryBytes))
        }

        cpuSamples.sort { $0.cpuUsage > $1.cpuUsage }
        memorySamples.sort { $0.memoryBytes > $1.memoryBytes }

        return (Array(cpuSamples.prefix(10)), Array(memorySamples.prefix(10)))
    }

    private func readThermal() -> ThermalLevel {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleARMIODevice"))
        guard service != 0 else {
            // Fallback for Intel Macs
            return .nominal
        }
        IOObjectRelease(service)

        let thermalLevel = ProcessInfo.processInfo.thermalState
        switch thermalLevel {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}
