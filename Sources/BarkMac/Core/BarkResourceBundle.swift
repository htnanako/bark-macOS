import Foundation

enum BarkResourceBundle {
    private static let bundleName = "BarkMac_BarkMac.bundle"
    private final class BundleFinder {}

    static let bundle: Bundle? = {
        for candidate in candidateURLs {
            if let bundle = Bundle(url: candidate.appendingPathComponent(bundleName)) {
                return bundle
            }
        }
        return nil
    }()

    private static var candidateURLs: [URL] {
        let executableURL = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
        let roots: [URL] = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle(for: BundleFinder.self).bundleURL,
            executableURL.deletingLastPathComponent(),
        ]
        .compactMap { $0 }

        var candidates: [URL] = []
        var seenPaths = Set<String>()

        for root in roots {
            var current = root
            for _ in 0..<6 {
                if seenPaths.insert(current.path).inserted {
                    candidates.append(current)
                }
                let parent = current.deletingLastPathComponent()
                if parent.path == current.path {
                    break
                }
                current = parent
            }
        }

        return candidates
    }
}
