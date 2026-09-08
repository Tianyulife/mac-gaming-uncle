import XCTest
import IndieCore
import IndieCatalog

final class SteamLibraryLocationTests: XCTestCase {
    func testOfflineLibraryRetainsMembershipAndReconnects() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("library-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at:root) }
        let steam=root.appendingPathComponent("bottle/drive_c/Steam")
        let bottle=root.appendingPathComponent("bottle")
        let disk=root.appendingPathComponent("External SSD")
        try FileManager.default.createDirectory(at:steam.appendingPathComponent("steamapps"),withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:bottle.appendingPathComponent("dosdevices"),withIntermediateDirectories:true)
        try FileManager.default.createSymbolicLink(at:bottle.appendingPathComponent("dosdevices/d:"),withDestinationURL:disk)
        let vdf = #"""
        "libraryfolders" {
          "0" { "path" "C:\\Steam" }
          "1" { "path" "D:\\Steam Library" "apps" { "2379780" "60000000" } }
        }
        """#
        try Data(vdf.utf8).write(to:steam.appendingPathComponent("steamapps/libraryfolders.vdf"))
        let offline=SteamLibraryLocation.load(steamRoot:steam,bottleRoot:bottle)
        XCTAssertEqual(offline.count,2)
        XCTAssertFalse(offline[1].isAvailable)
        XCTAssertTrue(offline[1].appIDs.contains(2379780))
        XCTAssertEqual(offline[1].root?.path,disk.appendingPathComponent("Steam Library").path)
        try FileManager.default.createDirectory(at:disk.appendingPathComponent("Steam Library/steamapps/common/Balatro"),withIntermediateDirectories:true)
        let manifest = #"""
        "AppState" { "appid" "2379780" "name" "Balatro" "installdir" "Balatro" "buildid" "99" "StateFlags" "4" }
        """#
        try Data(manifest.utf8).write(to:disk.appendingPathComponent("Steam Library/steamapps/appmanifest_2379780.acf"))
        XCTAssertTrue(SteamLibraryLocation.load(steamRoot:steam,bottleRoot:bottle)[1].isAvailable)
        let games=try SteamScanner.scan(steamApps:steam.appendingPathComponent("steamapps"))
        XCTAssertEqual(games.count,1)
        XCTAssertTrue(games[0].isReadyToPlay)
        XCTAssertEqual(try WineDrivePaths.windowsPath(for:games[0].installDirectory,bottleRoot:bottle),"D:\\Steam Library\\steamapps\\common\\Balatro")
    }
}
