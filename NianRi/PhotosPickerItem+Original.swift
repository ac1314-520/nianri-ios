import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

extension PhotosPickerItem {
    /// 普通照片用 PhotosPicker 给的数据就够；只有实况/GIF/WebP 才需要相册原图。
    var nianriNeedsOriginalAsset: Bool {
        supportedContentTypes.contains { type in
            type.identifier.contains("live-photo")
                || type.conforms(to: .gif)
                || type.conforms(to: .webP)
        }
    }
}
