import SwiftUI

struct MusicAttachmentView: View {
    @EnvironmentObject private var store: NianRiStore
    @ObservedObject private var player = AudioPlayer.shared

    let name: String?
    var title: String?
    var editable: Bool = false
    var onPick: () -> Void = {}
    var onRemove: () -> Void = {}

    private var fileURL: URL? { store.audioURL(for: name) }
    private var isPlaying: Bool { player.isPlaying(name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(name == nil ? Theme.paperDeep : Theme.cinnabarSoft)
                    Image(systemName: "music.note")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(name == nil ? Theme.muted : Theme.cinnabarDeep)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(name == nil ? "添加一段声音" : (title?.isEmpty == false ? title! : "这一天的声音"))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(player.lastError ?? (name == nil ? "从文件选择音乐，只保存在本机" : "轻点播放 · 已保存在本机"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(player.lastError == nil ? Theme.muted : Theme.cinnabar)
                        .lineLimit(2)
                }
                Spacer(minLength: 6)

                Button {
                    if let name, let fileURL {
                        player.toggle(name: name, url: fileURL)
                    } else if editable {
                        onPick()
                    }
                } label: {
                    Image(systemName: name == nil ? "plus" : (isPlaying ? "pause.fill" : "play.fill"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                        .frame(width: 38, height: 38)
                        .background(name == nil ? Theme.paperDeep : Theme.cinnabar)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(name == nil && !editable)
            }

            if editable, name != nil {
                HStack(spacing: 16) {
                    Spacer()
                    Button("更换") { onPick() }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.cinnabar)
                    Button("移除") {
                        player.stop()
                        onRemove()
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.muted)
                }
                .padding(.top, 8)
            }
        }
        .padding(13)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.line, lineWidth: 0.8)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if name == nil && editable { onPick() }
        }
    }
}
