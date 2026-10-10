import Foundation
import XCTest
@testable import IndieCore
@testable import IndieRuntime

final class WineRuntimeManagementTests: XCTestCase {
    private func runtime(_ root: URL, version: Int = 9, managed: Bool = true) -> LocalWineRuntime {
        let manifest = RuntimeManifest(
            id: managed ? CommunityIndieWineBootstrapper.runtimeID : "org.indie.wine.local",
            displayName: "Wine", version: SemanticVersion(major: 11, minor: 0, patch: version),
            channel: .experimental, hostArchitecture: .x86_64,
            minimumMacOS: SemanticVersion(major: 15, minor: 0),
            capabilities: RuntimeCapabilities(architectures: [.x86_64], renderers: [.wineD3D],
                supportsWoW64: true, supportsMSync: true), artifacts: [], licenses: [],
            publishedAt: Date(), signature: nil)
        return LocalWineRuntime(manifest: manifest, root: root, importedAt: Date())
    }

    func testExplicitSelectionAndMissingSelectionFallback() {
        let older = runtime(URL(fileURLWithPath: "/older"), version: 2)
        let newer = runtime(URL(fileURLWithPath: "/newer"))
        let generic = runtime(URL(fileURLWithPath: "/generic"), version: 99, managed: false)
        let installed = [generic, older, newer]
        XCTAssertEqual(LocalWineImporter.selectedGamingRuntime(in: installed, preferredID: older.id), older)
        XCTAssertEqual(LocalWineImporter.selectedGamingRuntime(in: installed, preferredID: "deleted"), newer)
        XCTAssertEqual(LocalWineImporter.selectedGamingRuntime(in: installed, preferredID: generic.id), newer)
        XCTAssertNil(LocalWineImporter.selectedGamingRuntime(in: [generic], preferredID: nil))
    }

    func testDeletionRejectsExternalDirectory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let external = root.appendingPathComponent("external")
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let importer = LocalWineImporter(paths: IndiePaths(root: root.appendingPathComponent("data")))
        do {
            try await importer.removeRuntime(runtime(external))
            XCTFail("Must reject unmanaged directories")
        } catch { XCTAssertTrue(FileManager.default.fileExists(atPath: external.path)) }
    }

    func testDeletionRejectsSymlinkOutsideRuntimeDirectory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = IndiePaths(root: root.appendingPathComponent("data"))
        let external = root.appendingPathComponent("external")
        let expected = paths.runtimes.appendingPathComponent(CommunityIndieWineBootstrapper.runtimeID).appendingPathComponent("11.0.9")
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: expected.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: expected, withDestinationURL: external)
        let value = runtime(expected)
        try IndieJSON.encoder().encode(value).write(to: external.appendingPathComponent("local-runtime.json"))
        do {
            try await LocalWineImporter(paths: paths).removeRuntime(value)
            XCTFail("Must reject an escaping symlink")
        } catch { XCTAssertTrue(FileManager.default.fileExists(atPath: external.path)) }
    }

    func testDeletionRejectsRunningRuntime() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = IndiePaths(root: root)
        let directory = paths.runtimes.appendingPathComponent(CommunityIndieWineBootstrapper.runtimeID).appendingPathComponent("11.0.9")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("sleep")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/bin/sleep"), to: executable)
        let value = runtime(directory)
        try IndieJSON.encoder().encode(value).write(to: directory.appendingPathComponent("local-runtime.json"))
        let process = Process()
        process.executableURL = executable
        process.arguments = ["30"]
        try process.run()
        defer { if process.isRunning { process.terminate() }; process.waitUntilExit() }
        XCTAssertTrue(WineProcessReaper.hasRunningProcesses(runtimeRoot: directory))
        do {
            try await LocalWineImporter(paths: paths).removeRuntime(value)
            XCTFail("Must reject a running version")
        } catch { XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path)) }
    }
}
