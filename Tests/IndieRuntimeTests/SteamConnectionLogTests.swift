import XCTest
import IndieRuntime

final class SteamConnectionLogTests: XCTestCase {
    func testLatestBackendEventOverridesCachedLoginSuccess() {
        XCTAssertFalse(SteamConnectionLog.isConnected(text:""))
        XCTAssertTrue(SteamConnectionLog.isConnected(text:"[Logged On, 3, 4]"))
        XCTAssertFalse(SteamConnectionLog.isConnected(text:"[Logged On, 3, 4]\n[Logged Off, 0, 0]"))
        XCTAssertTrue(SteamConnectionLog.isConnected(text:"[Logged On]\n[Logged Off]\n[Logged On]"))
        XCTAssertFalse(SteamConnectionLog.isConnected(text:"[Logged On]\n[Logged Off]\nUI login success"))
    }
}
