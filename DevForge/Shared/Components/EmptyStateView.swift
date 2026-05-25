import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (label: String, action: (() -> Void))?

    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.appHeadline)
            Text(message)
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let action {
                Button(action.label, action: action.action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, Spacing.sm)
            }
            Spacer()
        }
        .frame(maxWidth: 300)
        .padding()
    }
}
