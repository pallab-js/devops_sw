import Foundation
import CSMC

actor FanSpeedService {
    static let shared = FanSpeedService()

    struct FanInfo: Sendable {
        let index: Int
        let speedRPM: Float
    }

    func getFanCount() -> Int {
        guard SMCBridgeOpen() == 0 else { return 0 }
        let count = SMCBridgeGetFanCount()
        SMCBridgeClose()
        return Int(count)
    }

    func getAllFanSpeeds() -> [FanInfo] {
        guard SMCBridgeOpen() == 0 else { return [] }
        let count = SMCBridgeGetFanCount()
        var fans: [FanInfo] = []
        for i in 0..<Int(count) {
            let speed = SMCBridgeReadFanSpeed(Int32(i))
            fans.append(FanInfo(index: i, speedRPM: speed))
        }
        SMCBridgeClose()
        return fans
    }

    func getCPUTemperature() -> Float {
        guard SMCBridgeOpen() == 0 else { return -1 }
        let temp = SMCBridgeReadCPUTemperature()
        SMCBridgeClose()
        return temp
    }

    func getTemperatureSummary() -> String {
        guard SMCBridgeOpen() == 0 else { return "N/A" }
        let cpu = SMCBridgeReadCPUTemperature()
        let gpu = SMCBridgeReadGPUProximity()
        SMCBridgeClose()
        let cpuStr = cpu >= 0 ? String(format: "%.1f°C", cpu) : "N/A"
        let gpuStr = gpu >= 0 ? String(format: "%.1f°C", gpu) : "N/A"
        return "CPU: \(cpuStr) | GPU: \(gpuStr)"
    }
}
