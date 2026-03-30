import Foundation

struct BarkServerConfiguration: Codable, Equatable {
    var serverURL: String = "http://127.0.0.1:8080"
    var appID: String = "me.fin.bark.macos"
    var providerID: String = "macos_sse"
    var topic: String = "me.fin.bark.macos"
    var deviceKey: String = ""
    var streamToken: String = ""
    var lastEventID: String = ""
    var autoConnectOnLaunch: Bool = false
    var selectedTab: AppTab = .overview
    var encryption: BarkEncryptionConfiguration = .init()

    enum CodingKeys: String, CodingKey {
        case serverURL
        case appID
        case providerID
        case topic
        case deviceKey
        case streamToken
        case lastEventID
        case autoConnectOnLaunch
        case selectedTab
        case encryption
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serverURL = try container.decodeIfPresent(String.self, forKey: .serverURL) ?? "http://127.0.0.1:8080"
        appID = try container.decodeIfPresent(String.self, forKey: .appID) ?? "me.fin.bark.macos"
        providerID = try container.decodeIfPresent(String.self, forKey: .providerID) ?? "macos_sse"
        topic = try container.decodeIfPresent(String.self, forKey: .topic) ?? "me.fin.bark.macos"
        deviceKey = try container.decodeIfPresent(String.self, forKey: .deviceKey) ?? ""
        streamToken = try container.decodeIfPresent(String.self, forKey: .streamToken) ?? ""
        lastEventID = try container.decodeIfPresent(String.self, forKey: .lastEventID) ?? ""
        autoConnectOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .autoConnectOnLaunch) ?? false
        selectedTab = try container.decodeIfPresent(AppTab.self, forKey: .selectedTab) ?? .overview
        encryption = try container.decodeIfPresent(BarkEncryptionConfiguration.self, forKey: .encryption) ?? .init()
    }
}

enum BarkEncryptionAlgorithm: String, Codable, CaseIterable, Identifiable {
    case aes128 = "AES128"
    case aes192 = "AES192"
    case aes256 = "AES256"

    var id: String { rawValue }

    var keyLength: Int {
        switch self {
        case .aes128:
            return 16
        case .aes192:
            return 24
        case .aes256:
            return 32
        }
    }
}

enum BarkEncryptionMode: String, Codable, CaseIterable, Identifiable {
    case cbc = "CBC"
    case ecb = "ECB"
    case gcm = "GCM"

    var id: String { rawValue }

    var ivLength: Int? {
        switch self {
        case .cbc:
            return 16
        case .ecb:
            return nil
        case .gcm:
            return 12
        }
    }
}

struct BarkEncryptionConfiguration: Codable, Equatable {
    var algorithm: BarkEncryptionAlgorithm = .aes128
    var mode: BarkEncryptionMode = .cbc
    var key: String = ""
    var iv: String = ""

    var isConfigured: Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var ivPlaceholder: String {
        if let length = mode.ivLength {
            return "\(length) 字符"
        }
        return "当前模式不需要 IV"
    }
}

enum BarkBodyType: String, Codable {
    case plainText
    case markdown
}

enum BarkNotificationLevel: String, Codable {
    case active
    case passive
    case timeSensitive
    case critical
}

struct BarkResolvedNotification: Equatable {
    let eventID: String?
    let remoteID: String?
    let title: String
    let subtitle: String
    let body: String
    let bodyType: BarkBodyType
    let group: String?
    let urlString: String?
    let iconURLString: String?
    let imageURLString: String?
    let copyText: String?
    let soundName: String?
    let level: BarkNotificationLevel
    let volume: Double?
    let isCall: Bool
    let isAutoCopy: Bool
    let isArchive: Bool
    let isDeleteCommand: Bool
    let rawPayload: String
    let resolvedPayload: [String: AnyHashable]
    let receivedAt: Date

    init(
        eventID: String?,
        remoteID: String?,
        title: String,
        subtitle: String,
        body: String,
        bodyType: BarkBodyType,
        group: String?,
        urlString: String?,
        iconURLString: String? = nil,
        imageURLString: String? = nil,
        copyText: String?,
        soundName: String?,
        level: BarkNotificationLevel,
        volume: Double?,
        isCall: Bool,
        isAutoCopy: Bool,
        isArchive: Bool,
        isDeleteCommand: Bool,
        rawPayload: String,
        resolvedPayload: [String: AnyHashable],
        receivedAt: Date
    ) {
        self.eventID = eventID
        self.remoteID = remoteID
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.bodyType = bodyType
        self.group = group
        self.urlString = urlString
        self.iconURLString = iconURLString
        self.imageURLString = imageURLString
        self.copyText = copyText
        self.soundName = soundName
        self.level = level
        self.volume = volume
        self.isCall = isCall
        self.isAutoCopy = isAutoCopy
        self.isArchive = isArchive
        self.isDeleteCommand = isDeleteCommand
        self.rawPayload = rawPayload
        self.resolvedPayload = resolvedPayload
        self.receivedAt = receivedAt
    }

    var notificationIdentifier: String {
        if let remoteID, !remoteID.isEmpty {
            return "bark-remote-\(remoteID)"
        }
        if let eventID, !eventID.isEmpty {
            return "bark-event-\(eventID)"
        }
        return "bark-local-\(UUID().uuidString)"
    }

    var shouldDeliverLocalNotification: Bool {
        !isDeleteCommand
    }

    var actionContext: BarkNotificationActionContext {
        BarkNotificationActionContext(
            remoteID: remoteID,
            urlString: urlString,
            copyText: copyText,
            soundName: soundName,
            level: level,
            isCall: isCall,
            title: title,
            subtitle: subtitle,
            body: body
        )
    }
}

struct BarkNotificationRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let receivedAt: Date
    let remoteID: String?
    let title: String
    let subtitle: String
    let body: String
    let bodyType: BarkBodyType
    let group: String?
    let urlString: String?
    let iconURLString: String?
    let imageURLString: String?
    let copyText: String?
    let soundName: String?
    let level: BarkNotificationLevel
    let volume: Double?
    let isCall: Bool
    let isAutoCopy: Bool
    let isArchive: Bool
    let rawPayload: String

    init(
        id: UUID = UUID(),
        receivedAt: Date = .now,
        remoteID: String?,
        title: String,
        subtitle: String = "",
        body: String,
        bodyType: BarkBodyType = .plainText,
        group: String? = nil,
        urlString: String? = nil,
        iconURLString: String? = nil,
        imageURLString: String? = nil,
        copyText: String? = nil,
        soundName: String? = nil,
        level: BarkNotificationLevel = .active,
        volume: Double? = nil,
        isCall: Bool = false,
        isAutoCopy: Bool = false,
        isArchive: Bool = true,
        rawPayload: String
    ) {
        self.id = id
        self.receivedAt = receivedAt
        self.remoteID = remoteID
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.bodyType = bodyType
        self.group = group
        self.urlString = urlString
        self.iconURLString = iconURLString
        self.imageURLString = imageURLString
        self.copyText = copyText
        self.soundName = soundName
        self.level = level
        self.volume = volume
        self.isCall = isCall
        self.isAutoCopy = isAutoCopy
        self.isArchive = isArchive
        self.rawPayload = rawPayload
    }

    init(resolved: BarkResolvedNotification) {
        self.init(
            receivedAt: resolved.receivedAt,
            remoteID: resolved.remoteID,
            title: resolved.title,
            subtitle: resolved.subtitle,
            body: resolved.body,
            bodyType: resolved.bodyType,
            group: resolved.group,
            urlString: resolved.urlString,
            iconURLString: resolved.iconURLString,
            imageURLString: resolved.imageURLString,
            copyText: resolved.copyText,
            soundName: resolved.soundName,
            level: resolved.level,
            volume: resolved.volume,
            isCall: resolved.isCall,
            isAutoCopy: resolved.isAutoCopy,
            isArchive: resolved.isArchive,
            rawPayload: resolved.rawPayload
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        receivedAt = try container.decodeIfPresent(Date.self, forKey: .receivedAt) ?? .now
        remoteID = try container.decodeIfPresent(String.self, forKey: .remoteID)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        bodyType = try container.decodeIfPresent(BarkBodyType.self, forKey: .bodyType) ?? .plainText
        group = try container.decodeIfPresent(String.self, forKey: .group)
        urlString = try container.decodeIfPresent(String.self, forKey: .urlString)
        iconURLString = try container.decodeIfPresent(String.self, forKey: .iconURLString)
        imageURLString = try container.decodeIfPresent(String.self, forKey: .imageURLString)
        copyText = try container.decodeIfPresent(String.self, forKey: .copyText)
        soundName = try container.decodeIfPresent(String.self, forKey: .soundName)
        level = try container.decodeIfPresent(BarkNotificationLevel.self, forKey: .level) ?? .active
        volume = try container.decodeIfPresent(Double.self, forKey: .volume)
        isCall = try container.decodeIfPresent(Bool.self, forKey: .isCall) ?? false
        isAutoCopy = try container.decodeIfPresent(Bool.self, forKey: .isAutoCopy) ?? false
        isArchive = try container.decodeIfPresent(Bool.self, forKey: .isArchive) ?? true
        let storedRawPayload = try container.decodeIfPresent(String.self, forKey: .rawPayload)
        let legacyPayload = try container.decodeIfPresent(String.self, forKey: .payload)
        rawPayload = storedRawPayload ?? legacyPayload ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(receivedAt, forKey: .receivedAt)
        try container.encodeIfPresent(remoteID, forKey: .remoteID)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(body, forKey: .body)
        try container.encode(bodyType, forKey: .bodyType)
        try container.encodeIfPresent(group, forKey: .group)
        try container.encodeIfPresent(urlString, forKey: .urlString)
        try container.encodeIfPresent(iconURLString, forKey: .iconURLString)
        try container.encodeIfPresent(imageURLString, forKey: .imageURLString)
        try container.encodeIfPresent(copyText, forKey: .copyText)
        try container.encodeIfPresent(soundName, forKey: .soundName)
        try container.encode(level, forKey: .level)
        try container.encodeIfPresent(volume, forKey: .volume)
        try container.encode(isCall, forKey: .isCall)
        try container.encode(isAutoCopy, forKey: .isAutoCopy)
        try container.encode(isArchive, forKey: .isArchive)
        try container.encode(rawPayload, forKey: .rawPayload)
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名推送" : trimmed
    }

    var displayBody: String {
        let primaryBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primaryBody.isEmpty {
            return primaryBody
        }

        let secondary = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !secondary.isEmpty {
            return secondary
        }
        return "无内容"
    }

    var secondaryTagText: String? {
        let preferred = [group, subtitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return preferred
    }

    var combinedText: String {
        [displayTitle, subtitle, body]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    var payload: String {
        rawPayload
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case receivedAt
        case remoteID
        case title
        case subtitle
        case body
        case bodyType
        case group
        case urlString
        case iconURLString
        case imageURLString
        case copyText
        case soundName
        case level
        case volume
        case isCall
        case isAutoCopy
        case isArchive
        case rawPayload
        case payload
    }
}

struct BarkNotificationActionContext: Equatable {
    let remoteID: String?
    let urlString: String?
    let copyText: String?
    let soundName: String?
    let level: BarkNotificationLevel
    let isCall: Bool
    let title: String
    let subtitle: String
    let body: String

    init(
        remoteID: String?,
        urlString: String?,
        copyText: String?,
        soundName: String? = nil,
        level: BarkNotificationLevel = .active,
        isCall: Bool = false,
        title: String,
        subtitle: String,
        body: String
    ) {
        self.remoteID = remoteID
        self.urlString = urlString
        self.copyText = copyText
        self.soundName = soundName
        self.level = level
        self.isCall = isCall
        self.title = title
        self.subtitle = subtitle
        self.body = body
    }

    init(userInfo: [AnyHashable: Any]) {
        remoteID = userInfo[BarkNotificationUserInfoKeys.remoteID] as? String
        urlString = userInfo[BarkNotificationUserInfoKeys.url] as? String
        copyText = userInfo[BarkNotificationUserInfoKeys.copyText] as? String
        soundName = userInfo[BarkNotificationUserInfoKeys.soundName] as? String
        let levelValue = userInfo[BarkNotificationUserInfoKeys.level] as? String ?? BarkNotificationLevel.active.rawValue
        level = BarkNotificationLevel(rawValue: levelValue) ?? .active
        isCall = (userInfo[BarkNotificationUserInfoKeys.isCall] as? Bool) ?? false
        title = userInfo[BarkNotificationUserInfoKeys.title] as? String ?? ""
        subtitle = userInfo[BarkNotificationUserInfoKeys.subtitle] as? String ?? ""
        body = userInfo[BarkNotificationUserInfoKeys.body] as? String ?? ""
    }

    var fallbackCopyText: String {
        let preferred = copyText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let preferred, !preferred.isEmpty {
            return preferred
        }

        let fallback = [title, subtitle, body]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return fallback
    }

    var userInfo: [String: Any] {
        var userInfo: [String: Any] = [
            BarkNotificationUserInfoKeys.title: title,
            BarkNotificationUserInfoKeys.subtitle: subtitle,
            BarkNotificationUserInfoKeys.body: body,
        ]
        if let remoteID, !remoteID.isEmpty {
            userInfo[BarkNotificationUserInfoKeys.remoteID] = remoteID
        }
        if let urlString, !urlString.isEmpty {
            userInfo[BarkNotificationUserInfoKeys.url] = urlString
        }
        if let copyText, !copyText.isEmpty {
            userInfo[BarkNotificationUserInfoKeys.copyText] = copyText
        }
        if let soundName, !soundName.isEmpty {
            userInfo[BarkNotificationUserInfoKeys.soundName] = soundName
        }
        userInfo[BarkNotificationUserInfoKeys.level] = level.rawValue
        userInfo[BarkNotificationUserInfoKeys.isCall] = isCall
        return userInfo
    }
}

enum BarkNotificationCategory {
    static let identifier = "me.fin.bark.macos.notification"
    static let copyAction = "copy"
    static let openAction = "open"
}

enum BarkNotificationUserInfoKeys {
    static let remoteID = "bark.remote_id"
    static let url = "bark.url"
    static let copyText = "bark.copy_text"
    static let soundName = "bark.sound_name"
    static let level = "bark.level"
    static let isCall = "bark.is_call"
    static let title = "bark.title"
    static let subtitle = "bark.subtitle"
    static let body = "bark.body"
}

struct BarkToastSignal: Equatable, Identifiable {
    let id = UUID()
    let message: String
    let symbolName: String
}

struct BarkRegisterRequest: Encodable {
    let deviceKey: String?
    let deviceToken: String?
    let platform: String
    let appID: String
    let providerID: String
    let topic: String

    enum CodingKeys: String, CodingKey {
        case deviceKey = "device_key"
        case deviceToken = "device_token"
        case platform
        case appID = "app_id"
        case providerID = "provider_id"
        case topic
    }
}

struct BarkAPIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: Int64?
}

struct BarkRegistrationData: Decodable {
    let key: String?
    let deviceKey: String?
    let deviceToken: String?
    let streamToken: String?
    let platform: String?
    let appID: String?
    let providerID: String?

    enum CodingKeys: String, CodingKey {
        case key
        case deviceKey = "device_key"
        case deviceToken = "device_token"
        case streamToken = "stream_token"
        case platform
        case appID = "app_id"
        case providerID = "provider_id"
    }
}

struct BarkServerInfo: Decodable {
    let version: String?
    let build: String?
    let arch: String?
    let commit: String?
    let devices: Int?
    let providers: [String]?
    let deviceSchemaVersion: Int?
    let activeDevices: Int?
    let invalidDevices: Int?

    enum CodingKeys: String, CodingKey {
        case version
        case build
        case arch
        case commit
        case devices
        case providers
        case deviceSchemaVersion = "device_schema_version"
        case activeDevices = "active_devices"
        case invalidDevices = "invalid_devices"
    }
}

enum BarkClientError: LocalizedError {
    case invalidServerURL
    case missingDeviceKey
    case missingStreamToken
    case invalidResponse
    case invalidCiphertextConfiguration(message: String)
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "服务端地址无效，请输入完整 URL。"
        case .missingDeviceKey:
            return "还没有拿到 device key，请先注册当前设备。"
        case .missingStreamToken:
            return "还没有拿到 stream token，请先注册当前设备。"
        case .invalidResponse:
            return "服务端响应格式无法识别。"
        case let .invalidCiphertextConfiguration(message):
            return message
        case let .server(message):
            return message
        }
    }
}

struct BarkSSEMessage {
    let id: String?
    let event: String
    let data: String
}
