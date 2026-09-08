import XCTest
@testable import IndieRuntime

final class SteamDownloadBridgeTests: XCTestCase {
    func testLoggedOutInstallNeverOpensWizardOrReconnects() async throws {
        try await assertBlockedInstallation(cachedLogin:false,connectionLog:"[Logged On]")
    }

    func testCachedLoginSuccessCannotOverrideBackendDisconnect() async throws {
        try await assertBlockedInstallation(cachedLogin:true,connectionLog:"[Logged On]\n[Logged Off]")
    }

    private func assertBlockedInstallation(cachedLogin:Bool,connectionLog:String) async throws {
        let (steam, root) = try fixture()
        defer { try? FileManager.default.removeItem(at: steam) }
        try FileManager.default.createDirectory(at:steam.appendingPathComponent("logs"),withIntermediateDirectories:true)
        try Data(connectionLog.utf8).write(to:steam.appendingPathComponent("logs/connection_log.txt"))
        let directory = root.appendingPathComponent("100-200")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try Data().write(to: directory.appendingPathComponent("ready"))
        let responder = Task.detached {
            var count = 0
            while !Task.isCancelled && count < 3 {
                for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                    where file.pathExtension == "request" {
                    let message = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
                    let id = message["id"] as! NSNumber
                    let result: [String: Any]
                    switch message["method"] as? String {
                    case "Target.getTargets": result = ["targetInfos": [["title":"SharedJSContext","targetId":"fixture"]]]
                    case "Target.attachToTarget": result = ["sessionId":"fixture"]
                    default:
                        let expression = (message["params"] as? [String: Any])?["expression"] as? String ?? ""
                        guard !expression.contains("OpenInstallWizard"), !expression.contains("User.Reconnect") else {
                            throw NSError(domain: "UnsafeUnauthenticatedOperation", code: 1)
                        }
                        result = ["result": ["value": cachedLogin]]
                    }
                    try FileManager.default.removeItem(at: file)
                    try JSONSerialization.data(withJSONObject: ["id":id,"result":result]).write(
                        to: directory.appendingPathComponent("\(id).response"), options: .atomic)
                    count += 1
                }
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        defer { responder.cancel() }
        let result = try await SteamDownloadBridge(steamDirectory: steam).install(appID: 2379780)
        try await responder.value
        XCTAssertEqual(result, .loginRequired)
    }
    func testCallbackNeverOverridesIncompleteManifest() {
        let completed = SteamBridgeDownload(appID: 2495980, completed: true, paused: false, errorCode: 0, progress: nil)
        let pending = SteamBridgeDownload(appID: 2495980, completed: false, paused: true, errorCode: 0, progress: 1)
        XCTAssertFalse(SteamDownloadBridge.permitsPlay(manifestReady: false, download: completed))
        XCTAssertFalse(SteamDownloadBridge.permitsPlay(manifestReady: true, download: pending))
        XCTAssertTrue(SteamDownloadBridge.permitsPlay(manifestReady: true, download: completed))
        XCTAssertTrue(SteamDownloadBridge.permitsPlay(manifestReady: true, download: nil))
    }
    private func fixture() throws -> (URL, URL) {
        let steam = FileManager.default.temporaryDirectory.appendingPathComponent("mgu-pipe-test-\(UUID())")
        try SteamDownloadBridge.prepare(steamDirectory: steam)
        return (steam, SteamDownloadBridge.mailboxRoot(steamDirectory: steam))
    }

    func testPrivatePermissionsAndSymlinkRejected() throws {
        let (steam, root) = try fixture()
        defer { try? FileManager.default.removeItem(at: steam) }
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: root.path)[.posixPermissions] as? NSNumber)?.intValue, 0o700)
        try FileManager.default.removeItem(at: root)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: steam)
        XCTAssertThrowsError(try SteamDownloadBridge.prepare(steamDirectory: steam))
    }

    func testStaleAndAmbiguousSessionsFailClosed() async throws {
        let (steam, root) = try fixture()
        defer { try? FileManager.default.removeItem(at: steam) }
        for name in ["100-200", "101-201"] {
            let directory = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            try Data().write(to: directory.appendingPathComponent("ready"))
        }
        let bridge = SteamDownloadBridge(steamDirectory: steam)
        do { _ = try await bridge.downloads(); XCTFail("Ambiguous sessions must not be selected") } catch {}
        for name in ["100-200", "101-201"] {
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -30)],
                ofItemAtPath: root.appendingPathComponent(name + "/ready").path)
        }
        do { _ = try await bridge.downloads(); XCTFail("Stale sessions must not be selected") } catch {}
    }

    func testPipeRoundTripUsesSignedIDsAndSanitizedSnapshot() async throws {
        let (steam, root) = try fixture()
        defer { try? FileManager.default.removeItem(at: steam) }
        let directory = root.appendingPathComponent("100-200")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try Data().write(to: directory.appendingPathComponent("ready"))
        let responder = Task.detached {
            var requests = 0
            while !Task.isCancelled && requests < 3 {
                for request in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                    where request.pathExtension == "request" {
                    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: request)) as! [String: Any]
                    let id = (json["id"] as! NSNumber).intValue
                    guard id > 0, id <= Int32.max else { throw NSError(domain: "invalid-id", code: 1) }
                    let result: [String: Any]
                    switch json["method"] as? String {
                    case "Target.getTargets": result = ["targetInfos": [["title": "SharedJSContext", "targetId": "fixture"]]]
                    case "Target.attachToTarget": result = ["sessionId": "fixture-session"]
                    default: result = ["result": ["value": [["appID": 2495980, "completed": false, "paused": false, "errorCode": 0, "progress": 0.6]]]]
                    }
                    try FileManager.default.removeItem(at: request)
                    try JSONSerialization.data(withJSONObject: ["id": id, "result": result]).write(
                        to: directory.appendingPathComponent("\(id).response"), options: .atomic)
                    requests += 1
                }
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        defer { responder.cancel() }
        let items = try await SteamDownloadBridge(steamDirectory: steam).downloads()
        try await responder.value
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.appID, 2495980)
        XCTAssertEqual(items.first?.progress, 0.6)
        XCTAssertEqual(items.first?.completed, false)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasSuffix(".response") })
    }

    func testInvalidAppIDsDoNotSendCommands() async throws {
        let (steam, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: steam) }
        let bridge = SteamDownloadBridge(steamDirectory: steam)
        for id in [UInt64(0), UInt64(UInt32.max) + 1] {
            do { _ = try await bridge.install(appID: id); XCTFail("Invalid AppID accepted") } catch {}
        }
    }
}
