import SwiftUI
import AVKit

struct LivePhotoPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: player)
                .ignoresSafeArea()
            Button {
                player.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(18)
        }
        .onAppear { player.play() }
        .onDisappear { player.pause() }
    }
}
