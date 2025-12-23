import XCTest
@testable import MindSync

final class UserPreferencesTests: XCTestCase {
    func testDefaultPreferencesEpilepsyDisclaimerIsNotAccepted() {
        let prefs = UserPreferences.default
        XCTAssertFalse(prefs.epilepsyDisclaimerAccepted)
        XCTAssertNil(prefs.epilepsyDisclaimerAcceptedAt)
    }
}
