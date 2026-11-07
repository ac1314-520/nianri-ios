import SwiftUI
import UIKit
import ImageIO

struct AnimatedPhotoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.image = Self.animatedImage(url: url)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if uiView.image == nil {
            uiView.image = Self.animatedImage(url: url)
        }
    }

    private static func animatedImage(url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return UIImage(contentsOfFile: url.path)
        }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            return UIImage(contentsOfFile: url.path)
        }
        var frames: [UIImage] = []
        var duration: Double = 0
        for index in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cg))
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
               let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                let delay = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                    ?? (gif[kCGImagePropertyGIFDelayTime] as? Double)
                    ?? 0.1
                duration += max(0.03, delay)
            } else {
                duration += 0.1
            }
        }
        guard !frames.isEmpty else { return nil }
        return UIImage.animatedImage(with: frames, duration: duration)
    }
}
