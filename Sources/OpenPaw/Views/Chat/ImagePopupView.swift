import SwiftUI

struct ImagePopupView: View {
    let item: MediaItem
    @Binding var isPresented: Bool
    @State private var loadedImage: NSImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }

                Spacer()

                if let nsImage = loadedImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(20)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }

                Spacer()
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(.clear)
        .onKeyPress(.escape, phases: .down) { _ in
            isPresented = false
            return .handled
        }
        .onAppear { loadImage() }
    }

    private func loadImage() {
        switch item {
        case .imageBase64(_, let data, _):
            loadedImage = NSImage(data: data)

        case .imageURL(_, let url, _):
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = NSImage(data: data) {
                    await MainActor.run { loadedImage = image }
                }
            }

        default:
            break
        }
    }
}
