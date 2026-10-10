import Foundation

/// Serializes filesystem work away from the UI actor. Download manifests can
/// refresh frequently while account information and activity use a slower cadence.
public actor SteamLibraryReader {
    public struct Snapshot: Sendable {
        public let records: [SteamGame]
        public let readyAppIDs: Set<UInt64>
        public let accountGames: [SteamAccountGame]
        public let activities: [UInt64: SteamGameActivity]
        public let libraries: [SteamLibraryLocation]
    }
    private var root: URL?
    private var lastFullRead: Date?
    private var lastRecordRead: Date?
    private var records: [SteamGame] = []
    private var accountGames: [SteamAccountGame] = []
    private var activities: [UInt64: SteamGameActivity] = [:]
    private var libraries: [SteamLibraryLocation] = []

    public init() {}

    public func read(steamRoot: URL, bottleRoot: URL, force: Bool = false, now: Date = Date()) throws -> Snapshot {
        let steamApps = steamRoot.appendingPathComponent("steamapps")
        if force || root != steamRoot || lastRecordRead.map({ now.timeIntervalSince($0) >= 1 }) != false {
            records = FileManager.default.fileExists(atPath: steamApps.path)
                ? try SteamScanner.scan(steamApps: steamApps) : []
            lastRecordRead = now
        }
        if force || root != steamRoot || lastFullRead.map({ now.timeIntervalSince($0) >= 5 }) != false {
            accountGames = try SteamAccountLibraryScanner.scan(steamRoot: steamRoot, installed: records)
            activities = SteamActivityScanner.scan(steamRoot: steamRoot)
            libraries = SteamLibraryLocation.load(steamRoot: steamRoot, bottleRoot: bottleRoot)
            root = steamRoot
            lastFullRead = now
        }
        // Installation readiness changes faster than the account scan cadence.
        let installedIDs = Set(records.filter(\.isReadyToPlay).map(\.appID))
        let games = accountGames.map {
            SteamAccountGame(appID: $0.appID, name: $0.name, playtimeMinutes: $0.playtimeMinutes,
                lastPlayed: $0.lastPlayed, isInstalled: installedIDs.contains($0.appID),
                localArtworkDirectory: $0.localArtworkDirectory, headerImageURL: $0.headerImageURL,
                description: $0.description)
        }
        return Snapshot(records: records, readyAppIDs: installedIDs, accountGames: games, activities: activities, libraries: libraries)
    }
}

public struct SteamMetadataRetryPolicy: Sendable {
    private var failures: [UInt64: (attempts: Int, retryAt: Date)] = [:]
    public init() {}
    public func canAttempt(_ appID: UInt64, now: Date = Date()) -> Bool {
        failures[appID].map { now >= $0.retryAt } ?? true
    }
    public mutating func failed(_ appID: UInt64, now: Date = Date()) {
        let attempts = min((failures[appID]?.attempts ?? 0) + 1, 6)
        let delay = min(300.0, 10.0 * pow(2, Double(attempts - 1)))
        failures[appID] = (attempts, now.addingTimeInterval(delay))
    }
    public mutating func succeeded(_ appID: UInt64) { failures[appID] = nil }
    public mutating func reset() { failures.removeAll() }
}
