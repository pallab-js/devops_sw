import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: "launchAtLogin") {
            try? SMAppService.mainApp.register()
        }
    }
}
