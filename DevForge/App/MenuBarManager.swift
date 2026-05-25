import SwiftUI

@available(macOS 13.0, *)
struct MenuBarExtraView: View {
    @State private var runningCount = 0
    @State private var dockerStatus = "unknown"

    var body: some View {
        HStack {
            Image(systemName: "terminal.fill")
            Text("\(runningCount)")
        }
    }
}
