import AppKit
import IndieRuntime

@MainActor
enum SteamClientActivation {
    /// Background install must not foreground Steam's install wizard. Exact mapped
    /// helper PIDs only: never hide games, other Wine bottles, or native macOS Steam.
    static func hide(_ snapshot: SteamClientProcessSnapshot) {
        for pid in snapshot.helperPIDs + snapshot.steamPIDs {
            NSRunningApplication(processIdentifier: pid)?.hide()
        }
    }

    /// Choose the process owning the actual Steam window, not a headless CEF renderer.
    /// Only PID, geometry and layer are read; no screen-recording permission is requested.
    static func show(_ snapshot: SteamClientProcessSnapshot) -> Bool {
        let allowed = Set(snapshot.steamPIDs + snapshot.helperPIDs)
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates: [(Int32, Double)] = windows.compactMap { window in
            guard let number = window[kCGWindowOwnerPID as String] as? NSNumber,
                  allowed.contains(number.int32Value),
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds),
                  frame.width >= 300, frame.height >= 200,
                  frame.width.isFinite, frame.height.isFinite else { return nil }
            return (number.int32Value, frame.width * frame.height)
        }
        guard let pid = candidates.max(by: { $0.1 < $1.1 })?.0,
              let application = NSRunningApplication(processIdentifier: pid) else { return false }
        // macOS 14+ requires the foreground requester to transfer activation rights.
        NSApplication.shared.yieldActivation(to: application)
        application.unhide()
        return application.activate(options: .activateAllWindows)
    }
}
