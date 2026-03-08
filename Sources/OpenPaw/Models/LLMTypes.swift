import Foundation

// MARK: - Wire Protocol

enum FrameType: String, Codable {
    case req
    case res
    case event
}

struct RequestFrame: Encodable {
    let type = FrameType.req
    let id: String
    let method: String
    let params: [String: AnyCodable]
}

struct ResponseFrame: Decodable {
    let type: FrameType
    let id: String?
    let ok: Bool?
    let payload: [String: AnyCodable]?
    let error: ResponseError?

    struct ResponseError: Decodable {
        let code: String?
        let message: String?
    }
}

struct EventFrame: Decodable {
    let type: FrameType
    let event: String
    let payload: [String: AnyCodable]?
}

struct IncomingFrame: Decodable {
    let type: FrameType
    let id: String?
    let ok: Bool?
    let payload: [String: AnyCodable]?
    let error: ResponseFrame.ResponseError?
    let event: String?
    let method: String?
}

// MARK: - AnyCodable (lightweight JSON wrapper)

struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }
    var dictValue: [String: Any]? { value as? [String: Any] }
    var arrayValue: [Any]? { value as? [Any] }
}

// MARK: - Errors

enum GatewayError: LocalizedError {
    case connectionFailed
    case handshakeFailed(String)
    case requestFailed(String)
    case disconnected
    case timeout

    var errorDescription: String? {
        switch self {
        case .connectionFailed: "Could not connect to gateway"
        case .handshakeFailed(let msg): "Handshake failed: \(msg)"
        case .requestFailed(let msg): "Request failed: \(msg)"
        case .disconnected: "Disconnected from gateway"
        case .timeout: "Request timed out"
        }
    }
}
