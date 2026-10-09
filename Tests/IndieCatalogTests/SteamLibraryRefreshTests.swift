import Foundation
import XCTest
@testable import IndieCatalog

final class SteamLibraryRefreshTests: XCTestCase {
    func testAccountCacheArrivingAfterLoginWithoutInstalledGames() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertTrue(try SteamAccountLibraryScanner.scan(steamRoot: root, installed: []).isEmpty)
        let config = root.appendingPathComponent("userdata/123/config/localconfig.vdf")
        try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        let text = """
        "UserLocalConfigStore" { "Software" { "Valve" { "Steam" { "apps" {
            "219990" { "Playtime" "120" "LastPlayed" "1788570000" }
        } } } } }
        """
        try text.write(to: config, atomically: true, encoding: .utf8)
        let games = try SteamAccountLibraryScanner.scan(steamRoot: root, installed: [])
        XCTAssertEqual(games.map(\.appID), [219990])
        XCTAssertFalse(games[0].isInstalled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("steamapps").path))
    }

    func testLocalAccountCacheReadOnly() async throws {
        guard let path = ProcessInfo.processInfo.environment["INDIE_TEST_STEAM_ROOT"] else {
            throw XCTSkip("Opt-in read-only check of a local Steam cache")
        }
        let games = try SteamAccountLibraryScanner.scan(steamRoot: URL(fileURLWithPath: path), installed: [])
        XCTAssertFalse(games.isEmpty)
        let snapshot = try await SteamLibraryReader().read(
            steamRoot: URL(fileURLWithPath: path), bottleRoot: URL(fileURLWithPath: path), force: true)
        XCTAssertTrue(Set(games.map(\.appID)).isSubset(of: Set(snapshot.accountGames.map(\.appID))))
        print("Local Steam cache: \(snapshot.accountGames.count) games")
    }
}
