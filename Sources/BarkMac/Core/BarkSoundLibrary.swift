import Foundation

enum BarkSoundLibrary {
    static func installBundledSoundsIfNeeded() {
        guard let soundDirectoryURL = userSoundDirectoryURL() else {
            return
        }
        guard let resourceBundle = BarkResourceBundle.bundle else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: soundDirectoryURL, withIntermediateDirectories: true)
        } catch {
            return
        }

        let bundledSoundURLs = resourceBundle.urls(forResourcesWithExtension: "caf", subdirectory: nil) ?? []
        for sourceURL in bundledSoundURLs {
            let destinationURL = soundDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent)
            installNotificationCompatibleSound(from: sourceURL, to: destinationURL)
        }
    }

    static func normalizedSoundName(_ rawName: String?) -> String? {
        guard let trimmed = rawName?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        if trimmed.contains(".") {
            return trimmed
        }
        return "\(trimmed).caf"
    }

    static func resolvedSoundURL(named rawName: String?) -> URL? {
        guard let soundName = normalizedSoundName(rawName) else {
            return nil
        }

        let moduleURL = BarkResourceBundle.bundle?.url(forResource: soundName, withExtension: nil)
        if let moduleURL {
            return moduleURL
        }

        if let resourceURL = Bundle.main.resourceURL {
            let bundledURL = resourceURL.appendingPathComponent(soundName)
            if FileManager.default.fileExists(atPath: bundledURL.path) {
                return bundledURL
            }
        }

        if let userSoundDirectoryURL = userSoundDirectoryURL() {
            let localURL = userSoundDirectoryURL.appendingPathComponent(soundName)
            if FileManager.default.fileExists(atPath: localURL.path) {
                return localURL
            }
        }

        return nil
    }

    private static func userSoundDirectoryURL() -> URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Sounds", isDirectory: true)
    }

    private static func installNotificationCompatibleSound(from sourceURL: URL, to destinationURL: URL) {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        if convertToNotificationCompatibleCAF(sourceURL: sourceURL, destinationURL: destinationURL) {
            return
        }

        try? FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    @discardableResult
    private static func convertToNotificationCompatibleCAF(sourceURL: URL, destinationURL: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            sourceURL.path,
            destinationURL.path,
            "-f", "caff",
            "-d", "ima4",
        ]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
