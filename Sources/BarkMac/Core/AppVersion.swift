import Foundation

enum AppVersion {
    static var marketingVersion: String {
        value(for: "CFBundleShortVersionString", fallback: "0.0.0")
    }

    static var buildNumber: String {
        value(for: "CFBundleVersion", fallback: "0")
    }

    static var displayString: String {
        let version = marketingVersion
        let build = buildNumber

        guard !build.isEmpty, build != version else {
            return version
        }

        return "\(version) (\(build))"
    }

    private static func value(for key: String, fallback: String) -> String {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return fallback
        }

        return rawValue
    }
}
