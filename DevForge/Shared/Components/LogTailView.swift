import SwiftUI

struct LogTailView: View {
    let logLines: [LogLine]
    @State private var autoScroll = true
    @State private var filterText = ""
    @State private var showErrorsOnly = false

    private var filteredLines: [LogLine] {
        var lines = logLines
        if showErrorsOnly {
            lines = lines.filter { $0.isError }
        }
        if !filterText.isEmpty {
            lines = lines.filter { $0.content.localizedCaseInsensitiveContains(filterText) }
        }
        return lines
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal)
                .padding(.vertical, Spacing.xxs)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(filteredLines) { line in
                            logLineView(line)
                                .id(line.id)
                        }
                    }
                    .font(.appMonospaceSmall)
                    .padding(Spacing.xs)
                }
                .onChange(of: filteredLines.count) { _, _ in
                    if autoScroll, let last = filteredLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(.black, in: Rectangle())
    }

    private var toolbar: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Filter...", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
            Toggle("Errors only", isOn: $showErrorsOnly)
                .toggleStyle(.checkbox)
                .controlSize(.small)
            Spacer()
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.checkbox)
                .controlSize(.small)
            Button("Clear") {
                // clearing is handled by parent via state
            }
        }
    }

    private func logLineView(_ line: LogLine) -> some View {
        HStack(alignment: .top, spacing: Spacing.xxs) {
            Text(line.timestamp.shortFormatted)
                .foregroundStyle(Color.logTimestamp)
                .frame(width: 60, alignment: .trailing)
            Text(line.content)
                .foregroundStyle(line.isError ? Color.logError : Color.logInfo)
                .textSelection(.enabled)
        }
    }
}
