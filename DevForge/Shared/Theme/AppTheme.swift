import SwiftUI

extension Color {
    static let appAccent = Color.accentColor
    static let appBackground = Color(.controlBackgroundColor)
    static let appSecondaryBackground = Color(.underPageBackgroundColor)
    static let appText = Color(.labelColor)
    static let appSecondaryText = Color(.secondaryLabelColor)
    static let appTertiaryText = Color(.tertiaryLabelColor)
    static let appSeparator = Color(.separatorColor)
    static let appSelectedBackground = Color(.selectedContentBackgroundColor)
    static let appSelectedText = Color(.selectedMenuItemTextColor)
    static let appBorder = Color(.gridColor)

    static let statusGreen = Color.green
    static let statusYellow = Color.yellow
    static let statusRed = Color.red
    static let statusGray = Color.gray
    static let logError = Color.red
    static let logWarning = Color.yellow
    static let logInfo = Color.primary
    static let logTimestamp = Color.secondary
}

extension Font {
    static let appTitle = Font.largeTitle
    static let appHeadline = Font.headline
    static let appSubheadline = Font.subheadline
    static let appBody = Font.body
    static let appCaption = Font.caption
    static let appTitle3 = Font.title3
    static let appMonospace = Font.system(.body, design: .monospaced)
    static let appMonospaceSmall = Font.system(.caption, design: .monospaced)
}

enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
