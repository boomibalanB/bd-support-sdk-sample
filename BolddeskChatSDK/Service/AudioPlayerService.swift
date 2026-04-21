import SwiftUI
import AVFoundation

class AudioPlayer: ObservableObject {
    private var player: AVPlayer?

    func playSound(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        player = AVPlayer(url: url)
        player?.play()
    }
}
