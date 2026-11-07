import SwiftUI
import PhotosUI
import Photos
import UIKit

/// 用系统 PHLivePhotoView 直接播放，避免自己拆 MOV 后因权限/时序播不了。
struct LivePhotoPlaybackView: UIViewRepresentable {
    let identifier: String

    func makeCoordinator() -> Coordinator { Coordinator(identifier: identifier) }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .black
        context.coordinator.load(into: view)
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        if context.coordinator.identifier != identifier {
            context.coordinator.identifier = identifier
            context.coordinator.load(into: uiView)
        }
    }

    final class Coordinator {
        var identifier: String
        private var loadedIdentifier: String?

        init(identifier: String) {
            self.identifier = identifier
        }

        func load(into view: PHLivePhotoView) {
            guard loadedIdentifier != identifier else { return }
            loadedIdentifier = identifier
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            guard let asset = result.firstObject else { return }
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: CGSize(width: 1600, height: 1600),
                contentMode: .aspectFit,
                options: options
            ) { photo, _ in
                guard let photo else { return }
                DispatchQueue.main.async {
                    view.livePhoto = photo
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        view.play()
                    }
                }
            }
        }
    }
}

struct LivePhotoNativeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let identifier: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            LivePhotoPlaybackView(identifier: identifier)
                .ignoresSafeArea()
            Button {
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
    }
}
