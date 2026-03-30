import CryptoSwift
import Foundation

struct BarkPayloadResolver {
    let encryption: BarkEncryptionConfiguration

    init(encryption: BarkEncryptionConfiguration = .init()) {
        self.encryption = encryption
    }

    func resolve(
        _ rawPayload: [String: Any],
        eventID: String? = nil,
        receivedAt: Date = .now
    ) throws -> BarkResolvedNotification {
        let rawPayloadText = prettyPrintedJSON(from: rawPayload) ?? fallbackDescription(for: rawPayload)
        let normalizedPayload = normalizeDictionary(rawPayload)
        let effectivePayload = try decryptedPayloadIfNeeded(from: normalizedPayload)

        let markdown = stringValue(for: "markdown", in: effectivePayload)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedBody: String
        let bodyType: BarkBodyType
        if let markdown, !markdown.isEmpty {
            parsedBody = renderMarkdown(markdown)
            bodyType = .markdown
        } else {
            parsedBody = stringValue(for: "body", in: effectivePayload) ?? ""
            bodyType = .plainText
        }

        let remoteID = stringValue(for: "id", in: effectivePayload)
        let level = notificationLevel(from: effectivePayload)
        let resolved = BarkResolvedNotification(
            eventID: eventID,
            remoteID: remoteID?.isEmpty == false ? remoteID : nil,
            title: stringValue(for: "title", in: effectivePayload) ?? "",
            subtitle: stringValue(for: "subtitle", in: effectivePayload) ?? "",
            body: parsedBody,
            bodyType: bodyType,
            group: normalizedOptionalString(for: "group", in: effectivePayload),
            urlString: normalizedOptionalString(for: "url", in: effectivePayload),
            iconURLString: normalizedOptionalString(for: "icon", in: effectivePayload),
            imageURLString: normalizedOptionalString(for: "image", in: effectivePayload),
            copyText: normalizedOptionalString(for: "copy", in: effectivePayload),
            soundName: BarkSoundLibrary.normalizedSoundName(
                normalizedOptionalString(for: "sound", in: effectivePayload)
            ),
            level: level,
            volume: normalizedVolume(for: "volume", in: effectivePayload),
            isCall: boolValue(for: "call", in: effectivePayload),
            isAutoCopy: autoCopyEnabled(in: effectivePayload),
            isArchive: archiveEnabled(in: effectivePayload),
            isDeleteCommand: boolValue(for: "delete", in: effectivePayload),
            rawPayload: rawPayloadText,
            resolvedPayload: effectivePayload,
            receivedAt: receivedAt
        )
        return resolved
    }

    private func decryptedPayloadIfNeeded(from payload: [String: AnyHashable]) throws -> [String: AnyHashable] {
        guard let ciphertext = stringValue(for: "ciphertext", in: payload), !ciphertext.isEmpty else {
            return payload
        }
        guard encryption.isConfigured else {
            throw BarkClientError.invalidCiphertextConfiguration(message: "收到 ciphertext，但当前未配置加密 key。")
        }

        let decryptedJSON = try decrypt(ciphertext: ciphertext, overrideIV: stringValue(for: "iv", in: payload))
        return normalizeDictionary(decryptedJSON)
    }

    private func decrypt(ciphertext: String, overrideIV: String?) throws -> [String: Any] {
        let algorithm = encryption.algorithm
        let key = encryption.key
        guard key.count == algorithm.keyLength else {
            throw BarkClientError.invalidCiphertextConfiguration(
                message: "加密 key 长度不正确，\(algorithm.rawValue) 需要 \(algorithm.keyLength) 个字符。"
            )
        }

        let ivValue: String
        switch encryption.mode {
        case .cbc:
            let iv = overrideIV?.isEmpty == false ? overrideIV! : encryption.iv
            guard iv.count == 16 else {
                throw BarkClientError.invalidCiphertextConfiguration(message: "CBC 模式需要 16 个字符的 IV。")
            }
            ivValue = iv
        case .gcm:
            let iv = overrideIV?.isEmpty == false ? overrideIV! : encryption.iv
            guard iv.count == 12 else {
                throw BarkClientError.invalidCiphertextConfiguration(message: "GCM 模式需要 12 个字符的 IV。")
            }
            ivValue = iv
        case .ecb:
            ivValue = ""
        }

        let mode: BlockMode
        let padding: Padding
        switch encryption.mode {
        case .cbc:
            mode = CBC(iv: ivValue.bytes)
            padding = .pkcs7
        case .ecb:
            mode = ECB()
            padding = .pkcs7
        case .gcm:
            mode = GCM(iv: ivValue.bytes, mode: .combined)
            padding = .noPadding
        }

        let aes = try AES(key: key.bytes, blockMode: mode, padding: padding)
        let decrypted = try aes.decrypt(Array(base64: ciphertext))
        guard let text = String(data: Data(decrypted), encoding: .utf8) else {
            throw BarkClientError.server(message: "ciphertext 解密后不是有效 UTF-8 文本。")
        }
        guard
            let data = text.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw BarkClientError.server(message: "ciphertext 解密结果不是有效 JSON。")
        }
        return object
    }

    private func renderMarkdown(_ markdown: String) -> String {
        if let attributed = try? AttributedString(markdown: markdown) {
            return String(attributed.characters)
                .replacingOccurrences(of: "\n\n+", with: "\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return markdown
            .replacingOccurrences(of: "\n\n+", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func notificationLevel(from payload: [String: AnyHashable]) -> BarkNotificationLevel {
        guard let level = stringValue(for: "level", in: payload)?.lowercased() else {
            return .active
        }
        switch level {
        case "critical":
            return .critical
        case "passive":
            return .passive
        case "timesensitive":
            return .timeSensitive
        default:
            return .active
        }
    }

    private func autoCopyEnabled(in payload: [String: AnyHashable]) -> Bool {
        boolValue(for: "autocopy", in: payload) || boolValue(for: "automaticallycopy", in: payload)
    }

    private func archiveEnabled(in payload: [String: AnyHashable]) -> Bool {
        if let explicit = payload["isarchive"] {
            return boolValue(explicit)
        }
        return true
    }

    private func normalizeDictionary(_ dictionary: [String: Any]) -> [String: AnyHashable] {
        var normalized: [String: AnyHashable] = [:]
        for (key, value) in dictionary {
            let loweredKey = key.lowercased()
            if let hashable = normalizeValue(value) {
                normalized[loweredKey] = hashable
            }
        }
        return normalized
    }

    private func normalizeValue(_ value: Any) -> AnyHashable? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue
            }
            return number.stringValue
        case let bool as Bool:
            return bool
        case let int as Int:
            return String(int)
        case let int64 as Int64:
            return String(int64)
        case let double as Double:
            return String(double)
        case let dictionary as [String: Any]:
            return prettyPrintedJSON(from: dictionary)
        case let array as [Any]:
            return array.map { String(describing: $0) }.joined(separator: ",")
        default:
            return String(describing: value)
        }
    }

    private func stringValue(for key: String, in payload: [String: AnyHashable]) -> String? {
        guard let value = payload[key.lowercased()] else { return nil }
        if let string = value as? String {
            return string
        }
        return String(describing: value)
    }

    private func normalizedOptionalString(for key: String, in payload: [String: AnyHashable]) -> String? {
        guard let value = stringValue(for: key, in: payload)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private func doubleValue(for key: String, in payload: [String: AnyHashable]) -> Double? {
        guard let value = stringValue(for: key, in: payload), let number = Double(value) else {
            return nil
        }
        return number
    }

    private func normalizedVolume(for key: String, in payload: [String: AnyHashable]) -> Double? {
        guard let rawValue = doubleValue(for: key, in: payload) else {
            return nil
        }
        if rawValue <= 1 {
            return min(max(rawValue, 0), 1)
        }
        return min(max(rawValue / 10, 0), 1)
    }

    private func boolValue(for key: String, in payload: [String: AnyHashable]) -> Bool {
        guard let value = payload[key.lowercased()] else { return false }
        return boolValue(value)
    }

    private func boolValue(_ value: AnyHashable) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        let string = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch string {
        case "1", "true", "yes", "y", "on":
            return true
        default:
            return false
        }
    }

    private func prettyPrintedJSON(from payload: [String: Any]) -> String? {
        guard
            JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return text
    }

    private func fallbackDescription(for payload: [String: Any]) -> String {
        payload
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }
}
