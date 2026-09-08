import Foundation
import IndieCore

/// Match mapped PE files, not generic Wine process names or stale login logs.
/// Exact host paths keep clients in different Wine prefixes separate.
public struct SteamClientProcessSnapshot: Sendable, Equatable {
    public let steamPIDs: [Int32]
    public let helperPIDs: [Int32]
    public var hasClients: Bool { !steamPIDs.isEmpty || !helperPIDs.isEmpty }

    public static func read(steamExecutable: URL) async throws -> Self {
        let root = steamExecutable.deletingLastPathComponent()
        let helpers = ["cef.win64", "cef.win7x64"].flatMap { directory in
            ["steamwebhelper.exe", "steamwebhelper_real.exe"].map {
                root.appendingPathComponent("bin/cef/\(directory)/\($0)").resolvingSymlinksInPath().path
            }
        }.filter { FileManager.default.fileExists(atPath: $0) }
        let main = steamExecutable.resolvingSymlinksInPath().path
        let result = try await Subprocess().run(URL(fileURLWithPath: "/usr/sbin/lsof"),
            arguments: ["-a", "-d", "txt", "-Fpn", "--", main] + helpers,
            timeout: .seconds(5), requireSuccess: false)
        guard result.status == 0 || (result.status == 1 && result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) else {
            throw IndieError.invalidData(L("无法确认 Steam 进程状态，请稍后重试"))
        }
        let snapshot = parse(result.stdout, mainPath: main, helperPaths: Set(helpers))
        guard result.status != 0 || snapshot.hasClients else {
            throw IndieError.invalidData(L("无法确认 Steam 进程状态，请稍后重试"))
        }
        return snapshot
    }

    public static func parse(_ output: String, mainPath: String, helperPaths: Set<String>) -> Self {
        var pid: Int32?
        var steam = Set<Int32>(), helpers = Set<Int32>()
        for line in output.split(whereSeparator: \.isNewline) {
            if line.first == "p" { pid = Int32(line.dropFirst()); continue }
            guard line.first == "n", let pid, pid > 1 else { continue }
            let path = URL(fileURLWithPath: String(line.dropFirst())).resolvingSymlinksInPath().path
            if path == mainPath { steam.insert(pid) }
            else if helperPaths.contains(path) { helpers.insert(pid) }
        }
        return Self(steamPIDs: steam.sorted(), helperPIDs: helpers.sorted())
    }
}
