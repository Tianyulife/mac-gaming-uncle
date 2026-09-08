import Foundation
import IndieCore

public enum WinePath {
    public static func windowsPath(for file: URL, in bottle: BottleRecord) throws -> String {
        try WineDrivePaths.windowsPath(for: file, bottleRoot: bottle.root)
    }
}
