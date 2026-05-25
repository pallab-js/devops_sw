import Testing
@testable import DevForge

struct SystemMetricsTests {
    @Test func byteConversionFormatted() {
        #expect(1024.bytesFormatted == "1.0 KB")
        #expect(1_048_576.bytesFormatted == "1.0 MB")
        #expect(1_073_741_824.bytesFormatted == "1.0 GB")
        #expect(0.bytesFormatted == "0.0 B")
    }

    @Test func durationFormatted() {
        #expect(0.durationFormatted == "0s")
        #expect(30.durationFormatted == "30s")
        #expect(120.durationFormatted == "2m 0s")
        #expect(3661.durationFormatted == "1h 1m 1s")
    }

    @Test func percentageFormatted() {
        #expect(50.0.percentageFormatted == "50.0%")
        #expect(100.0.percentageFormatted == "100.0%")
        #expect(0.0.percentageFormatted == "0.0%")
    }

    @Test func thermalLevelEnum() {
        #expect(ThermalLevel.nominal.rawValue == "Nominal")
        #expect(ThermalLevel.fair.rawValue == "Fair")
        #expect(ThermalLevel.serious.rawValue == "Serious")
        #expect(ThermalLevel.critical.rawValue == "Critical")
    }
}
