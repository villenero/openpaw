import SwiftData
import Foundation

@Model
final class Message {
    var id: UUID
    var role: String
    var content: String
    var mediaJSON: String?
    var createdAt: Date
    var conversation: Conversation?

    init(role: String, content: String, media: [MediaItem] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = .now
        if !media.isEmpty {
            self.mediaJSON = try? String(data: JSONEncoder().encode(media), encoding: .utf8)
        }
    }

    var mediaItems: [MediaItem] {
        guard let json = mediaJSON, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([MediaItem].self, from: data)) ?? []
    }
}
