import SwiftUI

/// Renders media items (images as horizontal grid, audio as inline players).
struct MediaContentView: View {
    let media: [MediaItem]

    private var images: [MediaItem] { media.filter(\.isImage) }
    private var audio: [MediaItem] { media.filter(\.isAudio) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Images: horizontal scroll if >3
            if !images.isEmpty {
                if images.count <= 3 {
                    HStack(spacing: 8) {
                        ForEach(images) { item in
                            ImageThumbnailView(item: item)
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(images) { item in
                                ImageThumbnailView(item: item)
                            }
                        }
                    }
                }
            }

            // Audio players
            ForEach(audio) { item in
                AudioPlayerView(item: item)
            }
        }
    }
}
