import Foundation

@propertyWrapper
struct AppPreference<T> {
    let key: String
    let defaultValue: T

    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct AppPreferences {
    @AppPreference("launchAtLogin", defaultValue: false)
    static var launchAtLogin: Bool

    @AppPreference("showMenuBarExtra", defaultValue: true)
    static var showMenuBarExtra: Bool

    @AppPreference("colorScheme", defaultValue: "auto")
    static var colorScheme: String

    @AppPreference("accentColor", defaultValue: "blue")
    static var accentColor: String
}
