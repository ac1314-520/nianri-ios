import Foundation
import AVFoundation
import Combine

final class AudioPlayer: ObservableObject {
    static let shared = AudioPlayer()

    @Published private(set) var playingName: String?

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    func isPlaying(_ name: String?) -> Bool {
        guard let name else { return false }
        return playingName == name && player?.rate != 0
    }

    func toggle(name: String, url: URL) {
        if playingName == name {
            player?.pause()
            player = nil
            playingName = nil
            removeObserver()
            return
        }
        stop()
        let item = AVPlayerItem(url: url)
        let next = AVPlayer(playerItem: item)
        player = next
        playingName = name
        removeObserver()
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
        next.play()
    }

    func stop() {
        player?.pause()
        player = nil
        playingName = nil
        removeObserver()
    }

    private func removeObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}
