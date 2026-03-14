import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    let item: MediaItem
    @State private var audioManager = AudioPlayerManager.shared
    @State private var audioData: Data?
    @State private var loadError = false

    private var itemID: UUID { item.id }

    private var isActive: Bool { audioManager.currentlyPlayingID == itemID }
    private var isPlaying: Bool { isActive && audioManager.isPlaying }
    private var currentTime: TimeInterval { isActive ? audioManager.currentTime : 0 }
    private var duration: TimeInterval { isActive ? audioManager.duration : cachedDuration }

    @State private var cachedDuration: TimeInterval = 0
    @AppStorage("colorTheme") private var colorTheme: String = ColorTheme.default_.rawValue

    private var themeAccent: Color {
        let t = ColorTheme.current(from: colorTheme)
        return Color(hex: t.accentHex) ?? .blue
    }

    var body: some View {
        HStack(spacing: 10) {
            // Play/Pause button
            Button {
                handlePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.body)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(loadError)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    Capsule()
                        .fill(themeAccent)
                        .frame(width: progressWidth(in: geo.size.width), height: 4)
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard isActive, duration > 0 else { return }
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            audioManager.seek(id: itemID, to: fraction * duration)
                        }
                )
            }
            .frame(height: 20)

            // Time label
            Text(timeLabel)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 320)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear { prepareAudio() }
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return totalWidth * CGFloat(currentTime / duration)
    }

    private var timeLabel: String {
        if duration > 0 {
            return "\(formatTime(currentTime)) / \(formatTime(duration))"
        }
        if loadError { return "Error" }
        return "--:-- / --:--"
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let mins = Int(t) / 60
        let secs = Int(t) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func handlePlayPause() {
        if isActive {
            audioManager.togglePlayPause(id: itemID)
        } else {
            switch item {
            case .audioBase64(_, let data, _):
                audioManager.play(id: itemID, data: data)
            case .audioURL(_, let url):
                audioManager.play(id: itemID, url: url)
            default:
                break
            }
        }
    }

    private func prepareAudio() {
        switch item {
        case .audioBase64(_, let data, _):
            audioData = data
            if let player = try? AVAudioPlayer(data: data) {
                cachedDuration = player.duration
            }
        case .audioURL:
            // Duration unknown until played
            break
        default:
            break
        }
    }
}
