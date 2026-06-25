//
//  CropStep.swift
//  GrowingUp
//
//  Swap-seam around the crop engine. The rest of the flow depends only on this
//  contract — (source image + slot shape) in, cropped image out.
//
//  A self-contained pan/zoom cropper: the image is shown at full brightness with
//  a dark surround outside a centred crop window (rectangle for the main picture,
//  circular guide for the widget). Pinch zooms at natural sensitivity; drag pans
//  within bounds so the window is always covered. Save maps the window back into
//  source-pixel space and crops the full-resolution image.
//

import SwiftUI

struct CropStep: View {
    private let source: UIImage
    private let shape: CropShape
    private let onComplete: (UIImage) -> Void
    private let onCancel: () -> Void

    /// Source pixel dimensions, used to map the on-screen window back to pixels.
    private let pxW: CGFloat
    private let pxH: CGFloat

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @State private var isGesturing = false

    private let maxZoom: CGFloat = 6
    private let inset: CGFloat = 16

    init(
        image: UIImage,
        shape: CropShape,
        onComplete: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let normalized = image.normalizedUp()
        self.source = normalized
        self.shape = shape
        self.onComplete = onComplete
        self.onCancel = onCancel
        if let cg = normalized.cgImage {
            self.pxW = CGFloat(cg.width)
            self.pxH = CGFloat(cg.height)
        } else {
            self.pxW = normalized.size.width * normalized.scale
            self.pxH = normalized.size.height * normalized.scale
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if containerSize.width > 0 {
                imageLayer
                surround
            }
            topBar
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { containerSize = proxy.size }
                    .onChange(of: proxy.size) { _, newValue in containerSize = newValue }
            }
        )
        .contentShape(Rectangle())
        .simultaneousGesture(dragGesture)
        .simultaneousGesture(zoomGesture)
        .statusBarHidden()
    }

    // MARK: - Layers

    private var imageLayer: some View {
        let display = baseDisplaySize(in: containerSize)
        return Image(uiImage: source)
            .resizable()
            .frame(width: display.width, height: display.height)
            .scaleEffect(scale)
            .offset(offset)
    }

    private var surround: some View {
        let window = windowRect(in: containerSize)
        return ZStack {
            // Dark mask everywhere except the crop window (even-odd fill).
            Path { path in
                path.addRect(CGRect(origin: .zero, size: containerSize))
                if shape.isCircular {
                    path.addEllipse(in: window)
                } else {
                    path.addRect(window)
                }
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

            windowBorder(window)

            if !shape.isCircular && isGesturing {
                thirdsGrid(window)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func windowBorder(_ window: CGRect) -> some View {
        if shape.isCircular {
            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 1)
                .frame(width: window.width, height: window.height)
                .position(x: window.midX, y: window.midY)
        } else {
            Rectangle()
                .stroke(.white.opacity(0.9), lineWidth: 1)
                .frame(width: window.width, height: window.height)
                .position(x: window.midX, y: window.midY)
        }
    }

    private func thirdsGrid(_ window: CGRect) -> some View {
        Path { path in
            for line in 1...2 {
                let lineX = window.minX + window.width * CGFloat(line) / 3
                path.move(to: CGPoint(x: lineX, y: window.minY))
                path.addLine(to: CGPoint(x: lineX, y: window.maxY))
                let lineY = window.minY + window.height * CGFloat(line) / 3
                path.move(to: CGPoint(x: window.minX, y: lineY))
                path.addLine(to: CGPoint(x: window.maxX, y: lineY))
            }
        }
        .stroke(.white.opacity(0.5), lineWidth: 0.5)
    }

    private var topBar: some View {
        VStack {
            HStack {
                circleButton(systemImage: "xmark", background: .black.opacity(0.35), action: onCancel)
                    .accessibilityLabel(Text("Cancel"))
                Spacer()
                circleButton(systemImage: "checkmark", background: Color.accentColor) {
                    onComplete(cropImage())
                }
                .accessibilityLabel(Text("Use photo"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Spacer()
        }
    }

    private func circleButton(systemImage: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(background, in: Circle())
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isGesturing = true
                let raw = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(raw)
            }
            .onEnded { _ in
                lastOffset = offset
                isGesturing = false
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                isGesturing = true
                scale = min(max(lastScale * value.magnification, 1), maxZoom)
                offset = clampedOffset(offset)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
                isGesturing = false
            }
    }

    // MARK: - Geometry

    /// The largest rect of the slot's aspect ratio that fits the container,
    /// inset on all sides. `.circle` uses a 1:1 (square) window.
    private func windowSize(in container: CGSize) -> CGSize {
        let availW = max(0, container.width - inset * 2)
        let availH = max(0, container.height - inset * 2)
        guard availW > 0, availH > 0 else { return .zero }
        let aspect = shape.aspectRatio // width / height
        if availW / availH > aspect {
            let height = availH
            return CGSize(width: height * aspect, height: height)
        } else {
            let width = availW
            return CGSize(width: width, height: width / aspect)
        }
    }

    private func windowRect(in container: CGSize) -> CGRect {
        let size = windowSize(in: container)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Points-per-source-pixel so the image aspect-fills the window at scale 1.
    private func baseScale(window: CGSize) -> CGFloat {
        guard pxW > 0, pxH > 0, window.width > 0, window.height > 0 else { return 1 }
        return max(window.width / pxW, window.height / pxH)
    }

    private func baseDisplaySize(in container: CGSize) -> CGSize {
        let window = windowSize(in: container)
        let scaleFactor = baseScale(window: window)
        return CGSize(width: pxW * scaleFactor, height: pxH * scaleFactor)
    }

    private func clampedOffset(_ proposed: CGSize) -> CGSize {
        guard containerSize.width > 0 else { return .zero }
        let window = windowSize(in: containerSize)
        let display = baseDisplaySize(in: containerSize)
        let maxX = max(0, (display.width * scale - window.width) / 2)
        let maxY = max(0, (display.height * scale - window.height) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    // MARK: - Crop

    private func cropImage() -> UIImage {
        guard containerSize.width > 0, let cg = source.cgImage else { return source }
        let window = windowSize(in: containerSize)
        let pointsPerPixel = baseScale(window: window) * scale
        guard pointsPerPixel > 0 else { return source }

        let cropW = window.width / pointsPerPixel
        let cropH = window.height / pointsPerPixel
        let centerX = CGFloat(cg.width) / 2 - offset.width / pointsPerPixel
        let centerY = CGFloat(cg.height) / 2 - offset.height / pointsPerPixel

        var rect = CGRect(x: centerX - cropW / 2, y: centerY - cropH / 2, width: cropW, height: cropH)
        // Keep the rect inside the image; offset clamping should already ensure
        // this, but guard against rounding at the extremes.
        rect.origin.x = min(max(0, rect.origin.x), CGFloat(cg.width) - rect.width)
        rect.origin.y = min(max(0, rect.origin.y), CGFloat(cg.height) - rect.height)
        rect = rect.integral

        guard let cropped = cg.cropping(to: rect) else { return source }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }
}

private extension UIImage {
    /// Bakes any EXIF orientation into the pixels so `cgImage` cropping (which
    /// ignores orientation) maps screen coordinates onto the right region.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
