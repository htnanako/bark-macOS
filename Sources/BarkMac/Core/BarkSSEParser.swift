import Foundation

struct BarkSSEParser {
    private var currentID: String?
    private var currentEvent: String = "message"
    private var dataLines: [String] = []

    mutating func consume(line: String) -> BarkSSEMessage? {
        if line.isEmpty {
            guard !dataLines.isEmpty else {
                reset()
                return nil
            }
            let message = BarkSSEMessage(
                id: currentID,
                event: currentEvent,
                data: dataLines.joined(separator: "\n")
            )
            reset()
            return message
        }

        if line.hasPrefix(":") {
            return nil
        }

        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let field = String(parts[0])
        let rawValue = parts.count > 1 ? String(parts[1]) : ""
        let value = rawValue.hasPrefix(" ") ? String(rawValue.dropFirst()) : rawValue

        switch field {
        case "id":
            currentID = value
        case "event":
            currentEvent = value.isEmpty ? "message" : value
        case "data":
            dataLines.append(value)
        default:
            break
        }
        return nil
    }

    private mutating func reset() {
        currentID = nil
        currentEvent = "message"
        dataLines.removeAll(keepingCapacity: true)
    }
}
