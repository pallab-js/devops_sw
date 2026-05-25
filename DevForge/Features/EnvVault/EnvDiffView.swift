import SwiftUI

struct EnvDiffView: View {
    let leftFile: EnvFile
    let rightFile: EnvFile
    @State private var leftVars: [EnvVariable] = []
    @State private var rightVars: [EnvVariable] = []
    @State private var error: ErrorMessage?

    var body: some View {
        HSplitView {
            envFileSide(file: leftFile, variables: leftVars, side: "left")
            envFileSide(file: rightFile, variables: rightVars, side: "right")
        }
        .task {
            await loadVariables()
        }
        .alert(item: $error) { err in
            Alert(title: Text("Error"), message: Text(err.message))
        }
    }

    private func envFileSide(file: EnvFile, variables: [EnvVariable], side: String) -> some View {
        VStack(alignment: .leading) {
            Text(file.name).font(.appHeadline)
                .padding()
            List {
                ForEach(variables) { variable in
                    HStack {
                        DiffIndicator(
                            status: diffStatus(
                                key: variable.key,
                                value: variable.value,
                                isSecret: variable.isSecret,
                                side: side
                            )
                        )
                        Text(variable.key).font(.appMonospaceSmall)
                        Spacer()
                        Text(variable.value).font(.appMonospaceSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func diffStatus(key: String, value: String, isSecret: Bool, side: String) -> DiffStatus {
        let leftKeys = Set(leftVars.map(\.key))
        let rightKeys = Set(rightVars.map(\.key))

        if side == "left" {
            if !rightKeys.contains(key) { return .removed }
            if let rv = rightVars.first(where: { $0.key == key }), rv.value != value {
                return .changed
            }
        } else {
            if !leftKeys.contains(key) { return .added }
            if let lv = leftVars.first(where: { $0.key == key }), lv.value != value {
                return .changed
            }
        }
        return .unchanged
    }

    private func loadVariables() async {
        do {
            leftVars = try await EnvVaultService.shared.loadVariables(for: leftFile.id)
            rightVars = try await EnvVaultService.shared.loadVariables(for: rightFile.id)
        } catch { self.error = ErrorMessage(message: error.localizedDescription) }
    }
}

enum DiffStatus {
    case added, removed, changed, unchanged

    var color: Color {
        switch self {
        case .added: .green
        case .removed: .red
        case .changed: .yellow
        case .unchanged: .clear
        }
    }
}

struct DiffIndicator: View {
    let status: DiffStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
    }
}
