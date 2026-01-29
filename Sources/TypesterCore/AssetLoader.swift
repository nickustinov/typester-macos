import AppKit

/// Utilities for loading app assets from bundle or development paths.
enum AssetLoader {
    /// Finds the path to an asset file, checking bundle resources first,
    /// then development paths for `swift run`.
    static func findAssetPath(filename: String) -> String? {
        // Try bundle Resources first (release build)
        if let bundlePath = Bundle.main.resourcePath {
            let path = bundlePath + "/" + filename
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try dev paths (swift run)
        var devPaths = [
            FileManager.default.currentDirectoryPath + "/Assets/" + filename,
            (ProcessInfo.processInfo.environment["PWD"] ?? "") + "/Assets/" + filename
        ]

        // Also try relative to executable (for swift run from different directory)
        if let execPath = Bundle.main.executablePath {
            let url = URL(fileURLWithPath: execPath)
                .deletingLastPathComponent() // debug
                .deletingLastPathComponent() // arm64-apple-macosx
                .deletingLastPathComponent() // .build
            devPaths.append(url.path + "/Assets/" + filename)
        }

        for path in devPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    /// Loads an image from the Assets folder, returning nil if not found.
    static func loadImage(named filename: String) -> NSImage? {
        guard let path = findAssetPath(filename: filename) else {
            return nil
        }
        return NSImage(contentsOfFile: path)
    }
}
