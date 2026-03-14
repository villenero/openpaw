import Foundation

/// Represents a media content part extracted from assistant messages.
enum MediaItem: Codable, Equatable, Identifiable {
    case imageBase64(id: UUID = UUID(), data: Data, mediaType: String)
    case imageURL(id: UUID = UUID(), url: URL, alt: String)
    case audioBase64(id: UUID = UUID(), data: Data, mediaType: String)
    case audioURL(id: UUID = UUID(), url: URL)

    var id: UUID {
        switch self {
        case .imageBase64(let id, _, _): id
        case .imageURL(let id, _, _): id
        case .audioBase64(let id, _, _): id
        case .audioURL(let id, _): id
        }
    }

    var isImage: Bool {
        switch self {
        case .imageBase64, .imageURL: true
        case .audioBase64, .audioURL: false
        }
    }

    var isAudio: Bool {
        switch self {
        case .audioBase64, .audioURL: true
        case .imageBase64, .imageURL: false
        }
    }
}

/// Result of parsing message content into text + media parts.
struct ParsedContent {
    var text: String = ""
    var media: [MediaItem] = []
}

/// An attachment staged in the input before sending.
struct PendingAttachment: Identifiable {
    let id = UUID()
    let data: Data
    let mimeType: String
    let fileName: String

    var isImage: Bool { mimeType.hasPrefix("image/") }
    var isAudio: Bool { mimeType.hasPrefix("audio/") }

    /// Size in bytes
    var size: Int { data.count }

    /// True if the file exceeds the 10 MB limit
    var isOversized: Bool { data.count > 10 * 1024 * 1024 }
}
