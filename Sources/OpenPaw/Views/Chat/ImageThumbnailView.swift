import SwiftUI

struct ImageThumbnailView: View {
    let item: MediaItem
    @State private var showPopup = false
    @State private var loadedImage: NSImage?
    @State private var loading = false
    @State private var failed = false

    var body: some View {
        Group {
            if let nsImage = loadedImage {
                let size = naturalSize(for: nsImage)
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            } else if failed {
                imagePlaceholder()
            } else {
                ProgressView()
                    .frame(width: 60, height: 60)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            if loadedImage != nil { showPopup = true }
        }
        .sheet(isPresented: $showPopup) {
            ImagePopupView(item: item, isPresented: $showPopup)
        }
        .onAppear { loadImage() }
    }

    /// Return natural pixel size capped at 400pt wide and 400pt tall.
    private func naturalSize(for image: NSImage) -> CGSize {
        let w = image.size.width
        let h = image.size.height
        guard w > 0, h > 0 else { return CGSize(width: 100, height: 100) }

        let maxDim: CGFloat = 400
        let scale = min(1, maxDim / max(w, h))
        return CGSize(width: round(w * scale), height: round(h * scale))
    }

    private func loadImage() {
        guard loadedImage == nil, !loading else { return }

        switch item {
        case .imageBase64(_, let data, _):
            loadedImage = NSImage(data: data)
            if loadedImage == nil { failed = true }

        case .imageURL(_, let url, _):
            loading = true
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = NSImage(data: data) {
                        await MainActor.run { loadedImage = image }
                    } else {
                        await MainActor.run { failed = true }
                    }
                } catch {
                    await MainActor.run { failed = true }
                }
                await MainActor.run { loading = false }
            }

        default:
            break
        }
    }

    private func imagePlaceholder() -> some View {
        ZStack {
            Color.secondary.opacity(0.1)
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
