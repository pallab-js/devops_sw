import Foundation

struct SystemSnapshot: Sendable {
    let cpuUsage: Double
    let cpuPerCore: [Double]
    let memoryUsedGB: Double
    let memoryWiredGB: Double
    let memoryCompressedGB: Double
    let memoryFreeGB: Double
    let diskReadMBs: Double
    let diskWriteMBs: Double
    let networkUpKBs: Double
    let networkDownKBs: Double
    let thermalLevel: ThermalLevel
    let gpuName: String?
    let gpuMemoryGB: Double?
    let fanCount: Int
    let fanSpeeds: [Float]
    let cpuTemperature: Float
    let timestamp: Date
}

enum ThermalLevel: String, Sendable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"

    var color: String {
        switch self {
        case .nominal: "green"
        case .fair: "yellow"
        case .serious: "orange"
        case .critical: "red"
        }
    }
}

struct ProcessInfoSample: Identifiable {
    let id = UUID()
    let pid: Int32
    let name: String
    let cpuUsage: Double
    let memoryBytes: UInt64
}
