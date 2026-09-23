@testable import AmpX
import XCTest

final class AmpXUserDefaultsTests: XCTestCase {
    func testTestsNeverUseTheUsersRealPreferences() {
        XCTAssertFalse(AmpXUserDefaults.app === UserDefaults.standard)
    }
}
