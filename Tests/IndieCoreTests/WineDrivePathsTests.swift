import XCTest
import IndieCore

final class WineDrivePathsTests: XCTestCase {
    func testExistingCDriveAndMappedExternalPaths() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("drive-path-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at:root) }
        let bottle = root.appendingPathComponent("bottle")
        let disk = root.appendingPathComponent("External SSD")
        try FileManager.default.createDirectory(at:bottle.appendingPathComponent("dosdevices"),withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:disk,withIntermediateDirectories:true)
        try FileManager.default.createSymbolicLink(at:bottle.appendingPathComponent("dosdevices/d:"),withDestinationURL:disk)
        try FileManager.default.createSymbolicLink(at:bottle.appendingPathComponent("dosdevices/z:"),withDestinationURL:URL(fileURLWithPath:"/"))
        XCTAssertEqual(try WineDrivePaths.windowsPath(for:bottle.appendingPathComponent("drive_c/Program Files/Game.exe"),bottleRoot:bottle),"C:\\Program Files\\Game.exe")
        XCTAssertEqual(try WineDrivePaths.windowsPath(for:disk.appendingPathComponent("Steam Library/游戏/game.exe"),bottleRoot:bottle),"D:\\Steam Library\\游戏\\game.exe")
        XCTAssertEqual(WineDrivePaths.hostURL(for:"d:\\Steam Library\\游戏\\game.exe",bottleRoot:bottle)?.standardizedFileURL,
                       disk.appendingPathComponent("Steam Library/游戏/game.exe").standardizedFileURL)
        let sibling = root.appendingPathComponent("External SSD 2/game.exe")
        XCTAssertTrue(try WineDrivePaths.windowsPath(for:sibling,bottleRoot:bottle).hasPrefix("Z:\\"))
    }

    func testMissingMappingsAndTraversalAreRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("missing-drive-\(UUID())")
        XCTAssertThrowsError(try WineDrivePaths.windowsPath(for:URL(fileURLWithPath:"/Volumes/SSD/game.exe"),bottleRoot:root))
        for path in ["D:\\Games", "C:relative", "C:\\..\\outside", "\\\\server\\share", "C:\\folder\\D:escape"] {
            XCTAssertNil(WineDrivePaths.hostURL(for:path,bottleRoot:root))
        }
    }
}
