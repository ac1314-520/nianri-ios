import SwiftUI

struct PhotoCropSheet: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let initialFocusX: CGFloat
    let initialFocusY: CGFloat
    let onConfirm: (CGFloat, CGFloat) -> Void

    @State private var offset: CGSize?
    @State private var zoom: CGFloat = 1
    @State private var dragStart: CGSize = .zero
    @State private var isDragging = false
    @State private var zoomStart: CGFloat = 1
    @State private var isZooming = false
    @State private var canvasSize: CGSize = .zero

    init(
        image: UIImage,
        focusX: CGFloat,
        focusY: CGFloat,
        onConfirm: @escaping (CGFloat, CGFloat) -> Void
    ) {
        self.image = image
        initialFocusX = focusX.cropClampedUnit()
        initialFocusY = focusY.cropClampedUnit()
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("拖动照片，或双指缩放，让想保留的画面落在框内。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.cream.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                GeometryReader { proxy in
                    let size = proxy.size
                    let metrics = metrics(for: size)
                    ZStack {
                        Color.black
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: metrics.drawWidth, height: metrics.drawHeight)
                            .offset(x: metrics.offset.width, y: metrics.offset.height)
                    }
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.cream.opacity(0.7), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDragging {
                                    dragStart = metrics.offset
                                    isDragging = true
                                }
                                offset = clamp(
                                    CGSize(
                                        width: dragStart.width + value.translation.width,
                                        height: dragStart.height + value.translation.height
                                    ),
                                    for: size
                                )
                            }
                            .onEnded { _ in isDragging = false }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                if !isZooming {
                                    zoomStart = zoom
                                    isZooming = true
                                }
                                zoom = min(max(zoomStart * value, 1), 3)
                            }
                            .onEnded { _ in isZooming = false }
                    )
                    .onAppear { canvasSize = size }
                    .onChange(of: size) { _, newSize in canvasSize = newSize }
                }
                .aspectRatio(4 / 3, contentMode: .fit)
                .padding(.horizontal, 18)

                Text("封面会按框的中心显示；之后还可以再点「调整封面位置」修改。")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.cream.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer(minLength: 6)

                HStack(spacing: 10) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.cream.opacity(0.7))
                    Spacer()
                    Button("居中") {
                        offset = nil
                        zoom = 1
                    }
                    .foregroundStyle(Theme.cream.opacity(0.8))
                    Button("使用这个位置") {
                        let focus = focus(for: canvasSize)
                        onConfirm(focus.x, focus.y)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.cinnabar)
                    .foregroundStyle(Theme.cream)
                    .clipShape(Capsule())
                }
                .font(.system(size: 13))
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
            }
            .padding(.top, 12)
            .background(Theme.ink.ignoresSafeArea())
            .navigationTitle("调整封面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.ink, for: .navigationBar)
        }
    }

    private struct Metrics {
        let drawWidth: CGFloat
        let drawHeight: CGFloat
        let offset: CGSize
    }

    private func baseDrawSize(for size: CGSize) -> CGSize {
        let scale = max(
            size.width / max(image.size.width, 1),
            size.height / max(image.size.height, 1)
        ) * zoom
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    private func initialOffset(for size: CGSize) -> CGSize {
        let draw = baseDrawSize(for: size)
        return CGSize(
            width: (size.width - draw.width) * (initialFocusX - 0.5),
            height: (size.height - draw.height) * (initialFocusY - 0.5)
        )
    }

    private func metrics(for size: CGSize) -> Metrics {
        let draw = baseDrawSize(for: size)
        let current = offset ?? initialOffset(for: size)
        let maxX = max(0, (draw.width - size.width) / 2)
        let maxY = max(0, (draw.height - size.height) / 2)
        return Metrics(
            drawWidth: draw.width,
            drawHeight: draw.height,
            offset: CGSize(
                width: min(max(current.width, -maxX), maxX),
                height: min(max(current.height, -maxY), maxY)
            )
        )
    }

    private func clamp(_ value: CGSize, for size: CGSize) -> CGSize {
        let draw = baseDrawSize(for: size)
        let maxX = max(0, (draw.width - size.width) / 2)
        let maxY = max(0, (draw.height - size.height) / 2)
        return CGSize(
            width: min(max(value.width, -maxX), maxX),
            height: min(max(value.height, -maxY), maxY)
        )
    }

    private func focus(for size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else {
            return CGPoint(x: initialFocusX, y: initialFocusY)
        }
        let metrics = metrics(for: size)
        let x = (0.5 - metrics.offset.width / max(metrics.drawWidth, 1)).cropClampedUnit()
        let y = (0.5 - metrics.offset.height / max(metrics.drawHeight, 1)).cropClampedUnit()
        return CGPoint(x: x, y: y)
    }
}

private extension CGFloat {
    func cropClampedUnit() -> CGFloat { Swift.min(Swift.max(self, 0), 1) }
}
