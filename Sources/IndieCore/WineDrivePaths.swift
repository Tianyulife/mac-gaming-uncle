import Foundation

/// Resolves only existing Wine drive mappings. Does not grant a new root-drive mapping.
public enum WineDrivePaths {
    public static func windowsPath(for file: URL, bottleRoot: URL) throws -> String {
        let candidate = file.standardizedFileURL
        let c = bottleRoot.appendingPathComponent("drive_c").standardizedFileURL
        if let relative = relative(candidate.path, to: c.path) {
            return "C:\\" + relative.replacingOccurrences(of: "/", with: "\\")
        }
        let physical = candidate.resolvingSymlinksInPath()
        let devices = bottleRoot.appendingPathComponent("dosdevices")
        let entries = (try? FileManager.default.contentsOfDirectory(at: devices, includingPropertiesForKeys: nil)) ?? []
        var mappings: [(String, URL)] = []
        for entry in entries {
            guard entry.lastPathComponent.range(of: #"^[a-zA-Z]:$"#, options: .regularExpression) != nil,
                  (try? FileManager.default.destinationOfSymbolicLink(atPath:entry.path)) != nil else { continue }
            mappings.append((String(entry.lastPathComponent.prefix(1)).uppercased(),entry.resolvingSymlinksInPath()))
        }
        mappings.sort { a,b in a.1.path.count == b.1.path.count ? a.0 < b.0 : a.1.path.count > b.1.path.count }
        for (letter, root) in mappings {
            if let relative = relative(physical.path, to: root.path) {
                return letter + ":\\" + relative.replacingOccurrences(of: "/", with: "\\")
            }
        }
        throw IndieError.invalidArgument(L("所选目录没有可用的 Wine 磁盘映射"))
    }

    public static func hostURL(for path: String, bottleRoot: URL) -> URL? {
        let value = path.replacingOccurrences(of: "\\\\", with: "\\")
        guard value.count >= 3, !value.contains("\0"), !value.contains("\n") else { return nil }
        let chars = Array(value.prefix(3))
        guard chars[0].isASCII, chars[0].isLetter, chars[1] == ":", chars[2] == "\\" || chars[2] == "/" else { return nil }
        let parts = value.dropFirst(3).replacingOccurrences(of: "\\", with: "/").split(separator: "/")
        guard !parts.contains(".."), !parts.contains(where: { $0.contains(":") }) else { return nil }
        let drive = String(chars[0]).lowercased()
        let base: URL
        if drive == "c" { base = bottleRoot.appendingPathComponent("drive_c") }
        else {
            let link = bottleRoot.appendingPathComponent("dosdevices/\(drive):")
            guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) else { return nil }
            base = destination.hasPrefix("/") ? URL(fileURLWithPath:destination) : link.deletingLastPathComponent().appendingPathComponent(destination).standardizedFileURL
        }
        return parts.reduce(base) { $0.appendingPathComponent(String($1)) }.standardizedFileURL
    }

    private static func relative(_ candidate: String, to root: String) -> String? {
        if candidate == root { return "" }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard candidate.hasPrefix(prefix) else { return nil }
        return String(candidate.dropFirst(prefix.count))
    }
}
