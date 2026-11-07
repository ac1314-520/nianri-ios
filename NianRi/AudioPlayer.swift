import Foundation
import AVFoundation
import Combine

final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayer()

    @Published private(set) var playingName: String?
    @Published private(set) var lastError: String?

    private var audio: AVAudioPlayer?

    private override init() {
        super.init()
    }

    func isPlaying(_ name: String?) -> Bool {
        guard let name else { return false }
        return playingName == name && (audio?.isPlaying ?? false)
    }

    func toggle(name: String, url: URL) {
        if playingName == name, let audio {
            if audio.isPlaying {
                audio.pause()
                playingName = nil
            } else {
                audio.play()
                playingName = name
            }
            return
        }
        stop()
        lastError = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            let next = try AVAudioPlayer(contentsOf: url)
            next.delegate = self
            next.prepareToPlay()
            guard next.play() else {
                lastError = "这段音乐无法播放，请换一个标准 MP3 / M4A 文件"
                return
            }
            audio = next
            playingName = name
        } catch {
            lastError = "这段音乐无法播放，请换一个标准 MP3 / M4A 文件"
            playingName = nil
            audio = nil
        }
    }

    func stop() {
        audio?.stop()
        audio = nil
        playingName = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if audio === player {
            audio = nil
            playingName = nil
        }
    }
}
