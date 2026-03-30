import Foundation

struct BarkAPIClient {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }()

    func ping(configuration: BarkServerConfiguration) async throws -> String {
        let request = try makeRequest(path: "/ping", configuration: configuration, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        let payload = try decoder.decode(BarkAPIResponse<EmptyPayload>.self, from: data)
        guard payload.code == 200 else {
            throw BarkClientError.server(message: payload.message)
        }
        return payload.message
    }

    func info(configuration: BarkServerConfiguration) async throws -> BarkServerInfo {
        let request = try makeRequest(path: "/info", configuration: configuration, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try decoder.decode(BarkServerInfo.self, from: data)
    }

    func register(configuration: BarkServerConfiguration) async throws -> BarkRegistrationData {
        var request = try makeRequest(path: "/register", configuration: configuration, method: "POST")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let payload = BarkRegisterRequest(
            deviceKey: configuration.deviceKey.isEmpty ? nil : configuration.deviceKey,
            deviceToken: nil,
            platform: "macos",
            appID: configuration.appID,
            providerID: configuration.providerID,
            topic: configuration.topic
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        let registerResponse = try decoder.decode(BarkAPIResponse<BarkRegistrationData>.self, from: data)
        guard registerResponse.code == 200, let data = registerResponse.data else {
            throw BarkClientError.server(message: registerResponse.message)
        }
        return data
    }

    func consumeEvents(
        configuration: BarkServerConfiguration,
        onMessage: @escaping @Sendable (BarkSSEMessage) -> Void
    ) async throws {
        guard !configuration.deviceKey.isEmpty else {
            throw BarkClientError.missingDeviceKey
        }
        guard !configuration.streamToken.isEmpty else {
            throw BarkClientError.missingStreamToken
        }

        var request = try makeRequest(path: "/events/\(configuration.deviceKey)", configuration: configuration, method: "GET")
        request.timeoutInterval = 0
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(configuration.streamToken)", forHTTPHeaderField: "Authorization")
        if !configuration.lastEventID.isEmpty {
            request.setValue(configuration.lastEventID, forHTTPHeaderField: "Last-Event-ID")
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try validateHTTPStatus(response)

        var parser = BarkSSEParser()
        var lineBuffer = Data()

        for try await byte in bytes {
            if byte == UInt8(ascii: "\n") {
                let line = decodeSSELine(from: lineBuffer)
                if let message = parser.consume(line: line) {
                    onMessage(message)
                }
                lineBuffer.removeAll(keepingCapacity: true)
                continue
            }

            lineBuffer.append(byte)
        }

        if !lineBuffer.isEmpty {
            let line = decodeSSELine(from: lineBuffer)
            if let message = parser.consume(line: line) {
                onMessage(message)
            }
        }

        throw BarkClientError.server(message: "事件流连接已关闭")
    }

    private func makeRequest(path: String, configuration: BarkServerConfiguration, method: String) throws -> URLRequest {
        guard var baseURL = URL(string: configuration.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw BarkClientError.invalidServerURL
        }

        if baseURL.path.isEmpty {
            baseURL.append(path: path)
        } else {
            baseURL.append(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = method
        request.timeoutInterval = 15
        return request
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        try validateHTTPStatus(response)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BarkClientError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            if
                let payload = try? decoder.decode(BarkAPIResponse<EmptyPayload>.self, from: data),
                !payload.message.isEmpty
            {
                throw BarkClientError.server(message: payload.message)
            }
            throw BarkClientError.server(message: "请求失败，HTTP \(httpResponse.statusCode)")
        }
    }

    private func validateHTTPStatus(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BarkClientError.invalidResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw BarkClientError.server(message: "请求失败，HTTP \(httpResponse.statusCode)")
        }
    }

    private func decodeSSELine(from data: Data) -> String {
        if
            let carriageReturn = "\r".utf8.first,
            data.last == carriageReturn
        {
            return String(decoding: data.dropLast(), as: UTF8.self)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

private struct EmptyPayload: Decodable {}
