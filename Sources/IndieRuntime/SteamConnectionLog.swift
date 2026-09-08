import Foundation

/// The login-dialog state can remain successful after CM disconnects (for example
/// when another client signs in). Do not equate that cached state with connectivity.
public enum SteamConnectionLog {
    public static func isConnected(steamDirectory: URL) -> Bool {
        let file = steamDirectory.appendingPathComponent("logs/connection_log.txt")
        guard let handle = try? FileHandle(forReadingFrom:file) else { return false }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd() else { return false }
        do {
            try handle.seek(toOffset: end > 1_000_000 ? end-1_000_000 : 0)
            let data = try handle.readToEnd() ?? Data()
            return isConnected(text:String(decoding:data,as:UTF8.self))
        } catch { return false }
    }

    public static func isConnected(text: String) -> Bool {
        guard let online = text.range(of:"[Logged On",options:.backwards)?.lowerBound else { return false }
        guard let offline = text.range(of:"[Logged Off",options:.backwards)?.lowerBound else { return true }
        return online > offline
    }
}
