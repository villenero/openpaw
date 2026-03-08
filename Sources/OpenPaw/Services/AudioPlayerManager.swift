import AVFoundation
import SwiftUI

@Observable
@MainActor
final class AudioPlayerManager {
    static let shared = AudioPlayerManager()

    private(set) var currentlyPlayingID: UUID?
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    private init() {}

    func play(id: UUID, data: Data) {
        // Stop any current playback
        stopCurrent()

        guard let audioPlayer = try? AVAudioPlayer(data: data) else { return }
        player = audioPlayer
        audioPlayer.prepareToPlay()
        duration = audioPlayer.duration
        currentTime = 0
        currentlyPlayingID = id
        audioPlayer.play()
        isPlaying = true
        startTimer()
    }

    func play(id: UUID, url: URL) {
        stopCurrent()

        // Download and play
        currentlyPlayingID = id
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard currentlyPlayingID == id else { return } // cancelled while downloading
                guard let audioPlayer = try? AVAudioPlayer(data: data) else { return }
                player = audioPlayer
                audioPlayer.prepareToPlay()
                duration = audioPlayer.duration
                currentTime = 0
                audioPlayer.play()
                isPlaying = true
                startTimer()
            } catch {
                if currentlyPlayingID == id {
                    stopCurrent()
                }
            }
        }
    }

    func togglePlayPause(id: UUID) {
        guard currentlyPlayingID == id, let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(id: UUID, to time: TimeInterval) {
        guard currentlyPlayingID == id, let player else { return }
        player.currentTime = time
        currentTime = time
    }

    func stop(id: UUID) {
        guard currentlyPlayingID == id else { return }
        stopCurrent()
    }

    private func stopCurrent() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentlyPlayingID = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if !player.isPlaying && self.currentTime >= self.duration - 0.1 {
                    self.stopCurrent()
                }
            }
        }
    }
}
