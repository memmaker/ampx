import Foundation

enum AmpXUserDefaults {
    /// The app's preferences store. Tests run hosted in the app, so under XCTest this is an
    /// isolated suite (reset once per run) instead of the user's real saved EQ, layout, playlist, etc.
    /// `UserDefaults` is documented thread-safe.
    nonisolated(unsafe) static let app: UserDefaults = {
        let isRunningUnderTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
        guard isRunningUnderTest else { return .standard }
        let suiteName = "com.ampx.macos.tests"
        UserDefaults().removePersistentDomain(forName: suiteName)
        return UserDefaults(suiteName: suiteName) ?? .standard
    }()
}
