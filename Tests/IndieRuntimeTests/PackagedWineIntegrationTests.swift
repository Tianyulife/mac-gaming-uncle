import Foundation
import XCTest
@testable import IndieCore
@testable import IndieRuntime

final class PackagedWineIntegrationTests: XCTestCase {
    func testPackagedRuntimeWithImportedD3DMetal() async throws {
        let settings = ProcessInfo.processInfo.environment
        guard let source = settings["INDIE_TEST_WINE_RUNTIME"],
              let renderer = settings["INDIE_TEST_D3DMETAL_ROOT"] else {
            throw XCTSkip("Set INDIE_TEST_WINE_RUNTIME and INDIE_TEST_D3DMETAL_ROOT for real GPU fixtures")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("indie-d3dmetal-integration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let installed = try await LocalWineImporter(paths: IndiePaths(root: root.appendingPathComponent("data")))
            .importRuntime(from: URL(fileURLWithPath: source, isDirectory: true))
        let provider = WineRuntimeProvider(manifest: installed.manifest, root: installed.root)
        let bottle = BottleRecord(name: "D3DMetal smoke", root: root.appendingPathComponent("bottle"), runtimeID: installed.manifest.id)
        let rendererRoot = URL(fileURLWithPath: renderer, isDirectory: true)
        let subprocess = Subprocess()
        do {
            try await provider.initializeBottle(bottle)
            try D3DMetalRendererPreparer.installBridge(rendererRoot: rendererRoot, version: "integration", bottle: bottle)
            var environment = try D3DMetalLaunchEnvironment.make(rendererRoot: rendererRoot, runtimeRoot: installed.root,
                                                                metalHUD: false, metalFX: false, metal4: false)
            environment["WINEDEBUG"] = "-all,err+all,+loaddll,+winemac"
            environment["DYLD_PRINT_LIBRARIES"] = "1"
            let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let fixtureDirectory = bottle.root.appendingPathComponent("drive_c/mgu-fixtures", isDirectory: true)
            try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
            for (name, directX) in [("indie-d3d11-fixture", DirectXVersion.d3d11), ("indie-d3d12-fixture", DirectXVersion.d3d12)] {
                let sourceFixture = repo.appendingPathComponent(".build/windows-fixtures/\(name).exe")
                let executable = fixtureDirectory.appendingPathComponent("\(name).exe")
                try FileManager.default.copyItem(at: sourceFixture, to: executable)
                XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path), executable.path)
                let analysis = GameAnalysis(identity: GameIdentity(executableName: executable.lastPathComponent),
                                           architecture: .x86_64, directX: directX, antiCheat: .none, importedLibraries: [])
                let plan = try LaunchPlanBuilder.build(executable: executable,
                    windowsExecutablePath: try WinePath.windowsPath(for: executable, in: bottle), bottle: bottle,
                    profile: LaunchProfile(runtimeID: installed.manifest.id, preferredRenderer: .d3dMetal,
                                           arguments: ["--smoke"], environment: environment),
                    analysis: analysis, recipe: nil,
                    installed: InstalledRenderers(available: [.d3dMetal], overlayPaths: [.d3dMetal: rendererRoot.appendingPathComponent("wine")]))
                let result = try await subprocess.run(provider.wineBinary, arguments: provider.launchArguments(for: plan),
                    environment: plan.environment.merging(["DYLD_LIBRARY_PATH": installed.root.appendingPathComponent("lib").path]) { _, host in host },
                    timeout: .seconds(60), requireSuccess: false)
                if let destination = settings["INDIE_TEST_D3DMETAL_LOGS"] {
                    let directory = URL(fileURLWithPath: destination, isDirectory: true)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try (result.stdout + result.stderr).write(to: directory.appendingPathComponent("\(name).log"), atomically: true, encoding: .utf8)
                }
                XCTAssertEqual(result.status, 0, "\(name): \(result.stderr.suffix(3000))")
                XCTAssertTrue(result.stderr.contains("libd3dshared.dylib"), "\(name) must load the imported D3DMetal library")
            }
        } catch {
            await provider.stopBottle(bottle)
            throw error
        }
        await provider.stopBottle(bottle)
    }

    /// Opt-in: installs a real extracted runtime through the product importer,
    /// then initializes a disposable bottle through the product provider.
    func testPackagedRuntimeImportAndBottleInitialization() async throws {
        guard let source = ProcessInfo.processInfo.environment["INDIE_TEST_WINE_RUNTIME"] else {
            throw XCTSkip("Set INDIE_TEST_WINE_RUNTIME to an extracted complete runtime")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("indie-runtime-integration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = IndiePaths(root: root.appendingPathComponent("应用 数据"))
        let installed = try await LocalWineImporter(paths: paths).importRuntime(
            from: URL(fileURLWithPath: source, isDirectory: true)
        )
        let provider = WineRuntimeProvider(manifest: installed.manifest, root: installed.root)
        let bottle = BottleRecord(name: "Packaged smoke", root: root.appendingPathComponent("测试 容器"), runtimeID: installed.manifest.id)
        let subprocess = Subprocess()
        let environment = ["WINEPREFIX": bottle.root.path,
                           "DYLD_LIBRARY_PATH": installed.root.appendingPathComponent("lib").path,
                           "WINEDEBUG": "-all"]
        let items = await provider.probeInstallation(at: installed.root)
        XCTAssertEqual(items.first?.severity, .pass)
        XCTAssertTrue(CommunityIndieWineBootstrapper.hasControllerSupport(installed.root))
        XCTAssertEqual(installed.manifest.id, CommunityIndieWineBootstrapper.runtimeID)
        XCTAssertEqual(installed.manifest.channel, .experimental)
        let version = try String(contentsOf: installed.root.appendingPathComponent("runtime-version.txt"), encoding: .utf8)
        XCTAssertEqual(installed.manifest.version.description, version.trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            try await provider.initializeBottle(bottle)
            let result = try await subprocess.run(provider.wineBinary,
                arguments: ["cmd", "/c", "echo MGU_PACKAGED_RUNTIME_OK"],
                environment: environment, timeout: .seconds(30))
            XCTAssertTrue(result.stdout.contains("MGU_PACKAGED_RUNTIME_OK"))
        } catch {
            _ = try? await subprocess.run(provider.wineserverBinary, arguments: ["-k"],
                environment: environment, timeout: .seconds(10))
            _ = try? await subprocess.run(provider.wineserverBinary, arguments: ["-w"],
                environment: environment, timeout: .seconds(10))
            throw error
        }
        _ = try await subprocess.run(provider.wineserverBinary, arguments: ["-k"],
            environment: environment, timeout: .seconds(10))
        _ = try await subprocess.run(provider.wineserverBinary, arguments: ["-w"],
            environment: environment, timeout: .seconds(10))
    }
}
