import Foundation
import Metal

actor GPUMetricsService {
    static let shared = GPUMetricsService()

    struct GPUInfo: Sendable {
        let name: String
        let isLowPower: Bool
        let recommendedMaxGB: Double
        let registryID: UInt64
        let utilizationEstimate: Double
    }

    func getGPUInfo() -> GPUInfo? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let util = estimateGPUUtilization(device: device)
        return GPUInfo(
            name: device.name,
            isLowPower: device.isLowPower,
            recommendedMaxGB: Double(device.recommendedMaxWorkingSetSize) / 1_073_741_824,
            registryID: device.registryID,
            utilizationEstimate: util
        )
    }

    func getAllGPUs() -> [GPUInfo] {
        MTLCopyAllDevices().map { device in
            GPUInfo(
                name: device.name,
                isLowPower: device.isLowPower,
                recommendedMaxGB: Double(device.recommendedMaxWorkingSetSize) / 1_073_741_824,
                registryID: device.registryID,
                utilizationEstimate: estimateGPUUtilization(device: device)
            )
        }
    }

    private func estimateGPUUtilization(device: MTLDevice) -> Double {
        var library: MTLLibrary?
        do {
            library = try device.makeDefaultLibrary(bundle: .main)
            if library == nil {
                library = try device.makeLibrary(source: gpuKernelSource, options: nil)
            }
        } catch {
            return 0
        }
        guard let lib = library,
              let function = lib.makeFunction(name: "gpu_benchmark"),
              let pipeline = try? device.makeComputePipelineState(function: function) else {
            return 0
        }
        let cmdQueue = device.makeCommandQueue()
        guard let queue = cmdQueue else { return 0 }
        let start = CFAbsoluteTimeGetCurrent()
        let iterations = 50
        for _ in 0..<iterations {
            guard let cmdBuffer = queue.makeCommandBuffer(),
                  let encoder = cmdBuffer.makeComputeCommandEncoder() else { continue }
            encoder.setComputePipelineState(pipeline)
            encoder.dispatchThreadgroups(
                MTLSize(width: 1, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
            )
            encoder.endEncoding()
            cmdBuffer.commit()
            cmdBuffer.waitUntilCompleted()
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        return min(elapsed * 10, 100)
    }

    private let gpuKernelSource = """
    #include <metal_stdlib>
    using namespace metal;
    kernel void gpu_benchmark(
        device float *output [[buffer(0)]],
        uint id [[thread_position_in_grid]]
    ) {
        float sum = 0.0;
        for (int i = 0; i < 10000; i++) {
            sum += sin(float(i)) * cos(float(i));
        }
        output[id] = sum;
    }
    """
}
