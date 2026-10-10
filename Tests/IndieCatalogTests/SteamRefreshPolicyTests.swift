import Foundation
import XCTest
@testable import IndieCatalog

final class SteamRefreshPolicyTests: XCTestCase {
    func testSearchIgnoresOlderResponseAndResponseAfterClear() {
        var state = SteamStoreSearchState()
        let older = state.begin("first")
        let newer = state.begin("second")
        state.complete([], requestID: older)
        XCTAssertEqual(state.phase, .loading)
        state.fail("old failure", requestID: older)
        XCTAssertNil(state.error)
        state.complete([], requestID: newer)
        XCTAssertEqual(state.phase, .empty)
        XCTAssertTrue(state.completed)
        XCTAssertNil(state.error)
        let pending = state.begin("third")
        state.reset("")
        state.fail("late failure", requestID: pending)
        XCTAssertEqual(state.phase, .idle)
    }

    func testSearchFailureIsDistinctFromNoResultsAndCanRetry() {
        var state = SteamStoreSearchState()
        state.reset("  portal  ")
        XCTAssertEqual(state.query, "portal")
        XCTAssertEqual(state.phase, .waiting)
        let request = state.begin("portal")
        state.fail("offline", requestID: request)
        XCTAssertFalse(state.completed)
        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.error, "offline")
        let retry = state.begin("portal")
        state.complete([], requestID: retry)
        XCTAssertEqual(state.phase, .empty)
        XCTAssertNil(state.error)
    }

    func testRetryBackoffIsBoundedAndSuccessClearsFailure() {
        var retry = SteamMetadataRetryPolicy()
        let now = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(retry.canAttempt(42, now: now))
        retry.failed(42, now: now)
        XCTAssertFalse(retry.canAttempt(42, now: now.addingTimeInterval(9)))
        XCTAssertTrue(retry.canAttempt(42, now: now.addingTimeInterval(10)))
        XCTAssertTrue(retry.canAttempt(43, now: now))
        for _ in 0..<10 { retry.failed(42, now: now) }
        XCTAssertFalse(retry.canAttempt(42, now: now.addingTimeInterval(299)))
        XCTAssertTrue(retry.canAttempt(42, now: now.addingTimeInterval(300)))
        retry.succeeded(42)
        XCTAssertTrue(retry.canAttempt(42, now: now))
        retry.failed(42, now: now)
        retry.reset()
        XCTAssertTrue(retry.canAttempt(42, now: now))
    }

    func testAccountScanCadenceForceRefreshAndRootChange() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = root.appendingPathComponent("userdata/123/config/localconfig.vdf")
        try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        func write(_ appID: Int) throws {
            try "\"UserLocalConfigStore\" { \"Software\" { \"Valve\" { \"Steam\" { \"apps\" { \"\(appID)\" { \"Playtime\" \"120\" } } } } } }"
                .write(to: config, atomically: true, encoding: .utf8)
        }
        let reader = SteamLibraryReader()
        let now = Date(timeIntervalSince1970: 1000)
        try write(42)
        let initial = try await reader.read(steamRoot: root, bottleRoot: root, now: now)
        XCTAssertEqual(initial.accountGames.map(\.appID), [42])
        try write(43)
        let frequent = try await reader.read(steamRoot: root, bottleRoot: root, now: now.addingTimeInterval(1))
        XCTAssertEqual(frequent.accountGames.map(\.appID), [42])
        let full = try await reader.read(steamRoot: root, bottleRoot: root, now: now.addingTimeInterval(5))
        XCTAssertEqual(full.accountGames.map(\.appID), [43])
        try write(44)
        let forced = try await reader.read(steamRoot: root, bottleRoot: root, force: true, now: now.addingTimeInterval(5.1))
        XCTAssertEqual(forced.accountGames.map(\.appID), [44])
        let other = try await reader.read(steamRoot: root.appendingPathComponent("other"), bottleRoot: root, now: now.addingTimeInterval(5.2))
        XCTAssertTrue(other.accountGames.isEmpty)
    }

    func testDownloadReadinessUpdatesBeforeFullAccountScan() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let apps = root.appendingPathComponent("steamapps")
        try FileManager.default.createDirectory(at: apps.appendingPathComponent("common/Test"), withIntermediateDirectories: true)
        let manifest = apps.appendingPathComponent("appmanifest_42.acf")
        func write(_ ready: Bool) throws {
            try "\"AppState\" { \"appid\" \"42\" \"name\" \"Test\" \"installdir\" \"Test\" \"buildid\" \"123\" \"StateFlags\" \"\(ready ? 4 : 6)\" \"BytesToDownload\" \"100\" \"BytesDownloaded\" \"\(ready ? 100 : 10)\" }"
                .write(to: manifest, atomically: true, encoding: .utf8)
        }
        let reader = SteamLibraryReader()
        let now = Date(timeIntervalSince1970: 1000)
        try write(false)
        let first = try await reader.read(steamRoot: root, bottleRoot: root, now: now)
        XCTAssertFalse(first.readyAppIDs.contains(42))
        try write(true)
        let cached = try await reader.read(steamRoot: root, bottleRoot: root, now: now.addingTimeInterval(0.5))
        XCTAssertFalse(cached.readyAppIDs.contains(42))
        let ready = try await reader.read(steamRoot: root, bottleRoot: root, now: now.addingTimeInterval(1))
        XCTAssertTrue(ready.readyAppIDs.contains(42))
        XCTAssertTrue(ready.accountGames.first?.isInstalled == true)
    }
}
