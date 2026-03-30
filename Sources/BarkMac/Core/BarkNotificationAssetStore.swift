import CryptoSwift
import Foundation
import UniformTypeIdentifiers
import UserNotifications

protocol BarkNotificationAssetServing {
    @MainActor
    func attachments(for notification: BarkResolvedNotification) async -> [UNNotificationAttachment]
}

struct BarkNotificationAssetDescriptor: Equatable {
    let identifier: String
    let urlString: String
}

struct BarkNotificationAssetStore: BarkNotificationAssetServing {
    private let fileManager: FileManager
    private let dataLoader: @Sendable (URL) async throws -> (Data, String?)
    private let baseDirectoryProvider: () -> URL

    init(
        fileManager: FileManager = .default,
        dataLoader: @escaping @Sendable (URL) async throws -> (Data, String?) = Self.defaultDataLoader,
        baseDirectoryProvider: @escaping () -> URL = Self.defaultBaseDirectory
    ) {
        self.fileManager = fileManager
        self.dataLoader = dataLoader
        self.baseDirectoryProvider = baseDirectoryProvider
    }

    @MainActor
    func attachments(for notification: BarkResolvedNotification) async -> [UNNotificationAttachment] {
        let descriptors = Self.assetDescriptors(for: notification)
        guard !descriptors.isEmpty else { return [] }

        var attachments: [UNNotificationAttachment] = []
        for descriptor in descriptors {
            do {
                let localURL = try await localFileURL(for: descriptor)
                let attachment = try UNNotificationAttachment(identifier: descriptor.identifier, url: localURL)
                attachments.append(attachment)
            } catch {
                continue
            }
        }
        return attachments
    }

    static func assetDescriptors(for notification: BarkResolvedNotification) -> [BarkNotificationAssetDescriptor] {
        if let imageURLString = normalizedAssetURL(notification.imageURLString) {
            return [.init(identifier: "image", urlString: imageURLString)]
        }
        if let iconURLString = normalizedAssetURL(notification.iconURLString) {
            return [.init(identifier: "icon", urlString: iconURLString)]
        }
        return []
    }

    static func cachedAssetURL(iconURLString: String?, imageURLString: String?) -> URL? {
        let descriptors: [BarkNotificationAssetDescriptor]
        if let imageURLString = normalizedAssetURL(imageURLString) {
            descriptors = [.init(identifier: "image", urlString: imageURLString)]
        } else if let iconURLString = normalizedAssetURL(iconURLString) {
            descriptors = [.init(identifier: "icon", urlString: iconURLString)]
        } else {
            descriptors = []
        }
        guard let descriptor = descriptors.first else {
            return nil
        }

        guard let sourceURL = URL(string: descriptor.urlString) else {
            return nil
        }
        if sourceURL.isFileURL {
            return sourceURL
        }

        let directory = defaultBaseDirectory()
        let prefix = "\(descriptor.identifier)-\(descriptor.urlString.bytes.sha256().toHexString())."
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        for case let candidateURL as URL in enumerator {
            if candidateURL.lastPathComponent.hasPrefix(prefix) {
                return candidateURL
            }
        }
        return nil
    }

    @MainActor
    private func localFileURL(for descriptor: BarkNotificationAssetDescriptor) async throws -> URL {
        guard let sourceURL = URL(string: descriptor.urlString) else {
            throw URLError(.badURL)
        }
        if sourceURL.isFileURL {
            return sourceURL
        }

        let directory = baseDirectoryProvider()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let cacheKey = descriptor.urlString.bytes.sha256().toHexString()
        if let existingURL = cachedFileURLIfPresent(for: descriptor.identifier, cacheKey: cacheKey, in: directory) {
            return existingURL
        }

        let (data, mimeType) = try await dataLoader(sourceURL)
        let fileExtension = inferredFileExtension(for: sourceURL, mimeType: mimeType)
        let localURL = directory.appendingPathComponent("\(descriptor.identifier)-\(cacheKey).\(fileExtension)")
        try data.write(to: localURL, options: .atomic)
        return localURL
    }

    @MainActor
    private func cachedFileURLIfPresent(for identifier: String, cacheKey: String, in directory: URL) -> URL? {
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        let prefix = "\(identifier)-\(cacheKey)."
        for case let candidateURL as URL in enumerator {
            if candidateURL.lastPathComponent.hasPrefix(prefix) {
                return candidateURL
            }
        }
        return nil
    }

    @MainActor
    private func inferredFileExtension(for sourceURL: URL, mimeType: String?) -> String {
        let pathExtension = sourceURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pathExtension.isEmpty {
            return pathExtension
        }

        if
            let mimeType,
            let type = UTType(mimeType: mimeType),
            let preferredExtension = type.preferredFilenameExtension
        {
            return preferredExtension
        }

        return "png"
    }

    private static func normalizedAssetURL(_ rawValue: String?) -> String? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        guard let url = URL(string: trimmed) else {
            return nil
        }
        if let scheme = url.scheme?.lowercased(), ["http", "https", "file"].contains(scheme) {
            return trimmed
        }
        return nil
    }

    private static func defaultBaseDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let base = caches ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("BarkNotificationAssets", isDirectory: true)
    }

    private static func defaultDataLoader(_ url: URL) async throws -> (Data, String?) {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, !(200 ..< 300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        return (data, response.mimeType)
    }
}
