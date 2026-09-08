import Foundation
import IndieCore

public struct SteamLibraryLocation: Identifiable, Sendable, Equatable {
    public let index: Int
    public let windowsPath: String
    public let root: URL?
    public let appIDs: Set<UInt64>
    public var id: String { windowsPath.replacingOccurrences(of: "/", with: "\\").lowercased() }
    public var isAvailable: Bool {
        guard let root else { return false }
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: root.path, isDirectory: &directory) && directory.boolValue
    }
    public var isWritable: Bool { isAvailable && root.map { FileManager.default.isWritableFile(atPath: $0.path) } == true }
    public var freeBytes: Int64? {
        guard isAvailable, let root else { return nil }
        return (try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
    }
    public var displayPath: String { root?.path ?? windowsPath }
    public var displayName: String { root?.lastPathComponent ?? windowsPath }
    public var volumeName: String? {
        guard isAvailable, let root else { return nil }
        return (try? root.resourceValues(forKeys:[.volumeNameKey]))?.volumeName
    }

    public static func load(steamRoot: URL, bottleRoot: URL) -> [Self] {
        let defaultPath = (try? WineDrivePaths.windowsPath(for: steamRoot, bottleRoot: bottleRoot)) ?? steamRoot.path
        var result: [Self] = []
        let file = steamRoot.appendingPathComponent("steamapps/libraryfolders.vdf")
        if let parsed = try? VDFParser.parse(url: file),
           let entries = parsed.first(where: { $0.key.lowercased() == "libraryfolders" })?.value.object {
            for (key,value) in entries {
                guard let index = Int(key), index >= 0 else { continue }
                let object = value.object ?? [:]
                guard let path = object.first(where: { $0.key.lowercased() == "path" })?.value.string ?? value.string else { continue }
                let apps = object.first(where: { $0.key.lowercased() == "apps" })?.value.object ?? [:]
                let root = path.hasPrefix("/") ? URL(fileURLWithPath:path) : WineDrivePaths.hostURL(for:path,bottleRoot:bottleRoot)
                result.append(.init(index:index,windowsPath:path,root:root,appIDs:Set(apps.keys.compactMap(UInt64.init))))
            }
        }
        if !result.contains(where: { $0.index == 0 }) {
            result.append(.init(index:0,windowsPath:defaultPath,root:steamRoot,appIDs:[]))
        }
        var unique: [String:Self] = [:]
        for library in result.sorted(by: { $0.index < $1.index }) {
            let key=library.root?.resolvingSymlinksInPath().path ?? library.id
            if let existing=unique[key] {
                unique[key] = .init(index:existing.index,windowsPath:existing.windowsPath,root:existing.root,appIDs:existing.appIDs.union(library.appIDs))
            } else { unique[key] = library }
        }
        return unique.values.sorted { $0.index < $1.index }
    }
}
