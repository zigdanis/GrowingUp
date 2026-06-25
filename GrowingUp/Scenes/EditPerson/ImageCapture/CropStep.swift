//
//  CropStep.swift
//  GrowingUp
//
//  Pan/zoom cropper. The image aspect-fills the screen at the minimum zoom that
//  covers it. Crop frame = full screen for the main picture, a circular guide in
//  the safe area for the widget. Save maps the frame back to source pixels.
//

import SwiftUI

struct CropStep: View {
    private let source: UIImage
    private let shape: CropShape
    private let onComplete: (UIImage) -> Void
    private let onCancel: () -> Void

    /// Source pixel dimensions, used to map the on-screen frame back to pixels.
    let pxW: CGFloat
    let pxH: CGFloat

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @State private var safeInsets = EdgeInsets()
    @State private var isGesturing = false

    let maxZoom: CGFloat = 6
    /// Gap between the circular guide and the safe-area edges.
    let framePadding: CGFloat = 14

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
        if let cgImage = normalized.cgImage {
            self.pxW = CGFloat(cgImage.width)
            self.pxH = CGFloat(cgImage.height)
        } else {
            self.pxW = normalized.size.width * normalized.scale
            self.pxH = normalized.size.height * normalized.scale
        }
    }

    var body: some View {
        // `.ignoresSafeArea()` makes `proxy.size` the real screen — one coordinate
        // space for image, clamp and crop. Insets come from the window so they
        // don't depend on how the ignoring reader reports them.
        GeometryReader { proxy in
            ZStack {
                cropContent
                    .contentShape(Rectangle())
                    .simultaneousGesture(dragGesture)
                    .simultaneousGesture(zoomGesture)
                topBar(insets: safeInsets)
            }
            .onAppear { updateContainer(proxy) }
            .onChange(of: proxy.size) { _, _ in updateContainer(proxy) }
        }
        .ignoresSafeArea()
        .statusBarHidden()
    }

    /// Capture the true screen size plus real window insets, then re-settle.
    private func updateContainer(_ proxy: GeometryProxy) {
        let full = proxy.size
        let insets = Self.windowSafeInsets
        containerSize = full
        safeInsets = insets
        let settled = clampOffset(offset, scale: scale, container: full, insets: insets)
        offset = settled
        lastOffset = settled
    }

    /// The active window's safe-area insets, read straight from UIKit.
    private static var windowSafeInsets: EdgeInsets {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first
        let inset = window?.safeAreaInsets ?? .zero
        return EdgeInsets(top: inset.top, leading: inset.left, bottom: inset.bottom, trailing: inset.right)
    }

    // MARK: - Layers

    private var cropContent: some View {
        ZStack {
            Color.black
            if containerSize.width > 0 {
                imageLayer
                surround
            }
        }
    }

    private var imageLayer: some View {
        let display = displaySize(in: containerSize)
        return Image(uiImage: source)
            .resizable()
            .frame(width: display.width, height: display.height)
            .scaleEffect(scale)
            .offset(offset)
            // Pin the footprint to the screen and clip overflow so the image stays
            // centred (offset 0 == aspect-fill, which the clamp assumes).
            .frame(width: containerSize.width, height: containerSize.height)
            .clipped()
    }

    @ViewBuilder private var surround: some View {
        let frame = frameRect(in: containerSize, insets: safeInsets)
        if shape.isCircular {
            ZStack {
                // Dark mask everywhere except the circular crop window.
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: containerSize))
                    path.addEllipse(in: frame)
                }
                .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 1)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
            .allowsHitTesting(false)
        } else if isGesturing {
            // Main picture crops full-screen: no surround, just a thirds guide.
            thirdsGrid(frame)
                .allowsHitTesting(false)
        }
    }

    private func thirdsGrid(_ frame: CGRect) -> some View {
        Path { path in
            for line in 1...2 {
                let lineX = frame.minX + frame.width * CGFloat(line) / 3
                path.move(to: CGPoint(x: lineX, y: frame.minY))
                path.addLine(to: CGPoint(x: lineX, y: frame.maxY))
                let lineY = frame.minY + frame.height * CGFloat(line) / 3
                path.move(to: CGPoint(x: frame.minX, y: lineY))
                path.addLine(to: CGPoint(x: frame.maxX, y: lineY))
            }
        }
        .stroke(.white.opacity(0.5), lineWidth: 0.5)
    }

    private func topBar(insets: EdgeInsets) -> some View {
        VStack {
            HStack {
                glassButton(systemImage: "xmark", prominent: false, action: onCancel)
                    .accessibilityLabel(Text("Cancel"))
                Spacer()
                glassButton(systemImage: "checkmark", prominent: true) {
                    onComplete(cropImage())
                }
                .accessibilityLabel(Text("Use photo"))
            }
            .padding(.horizontal, 20)
            // The ZStack ignores the safe area, so clear the notch manually.
            .padding(.top, insets.top + 8)
            Spacer()
        }
    }

    /// A circular Liquid Glass icon button. `prominent` is the accent-filled
    /// affirmative (checkmark); the plain glass (X) reads against its backdrop.
    private func glassButton(systemImage: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .modifier(GlassButtonChrome(prominent: prominent))
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
                offset = rubberBandOffset(raw, scale: scale, container: containerSize, insets: safeInsets)
            }
            .onEnded { _ in
                let settled = clampOffset(offset, scale: scale, container: containerSize, insets: safeInsets)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    offset = settled
                }
                lastOffset = settled
                isGesturing = false
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                isGesturing = true
                let newScale = rubberBandedScale(lastScale * value.magnification)
                scale = newScale
                offset = rubberBandOffset(offset, scale: newScale, container: containerSize, insets: safeInsets)
            }
            .onEnded { _ in
                let settledScale = min(max(scale, minScale(in: containerSize, insets: safeInsets)), maxZoom)
                let settledOffset = clampOffset(offset, scale: settledScale, container: containerSize, insets: safeInsets)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    scale = settledScale
                    offset = settledOffset
                }
                lastScale = settledScale
                lastOffset = settledOffset
                isGesturing = false
            }
    }
}

// MARK: - Geometry & crop math

extension CropStep {
    /// The region that must stay covered and gets cropped. Rectangle: the full
    /// screen. Circle: a square (persisted square) centred in the safe area.
    func frameRect(in container: CGSize, insets: EdgeInsets) -> CGRect {
        guard container.width > 0, container.height > 0 else { return .zero }
        guard shape.isCircular else {
            return CGRect(origin: .zero, size: container)
        }
        let availX = insets.leading + framePadding
        let availY = insets.top + framePadding
        let availW = max(0, container.width - insets.leading - insets.trailing - framePadding * 2)
        let availH = max(0, container.height - insets.top - insets.bottom - framePadding * 2)
        let side = min(availW, availH)
        guard side > 0 else { return .zero }
        return CGRect(
            x: availX + (availW - side) / 2,
            y: availY + (availH - side) / 2,
            width: side,
            height: side
        )
    }

    /// Points-per-source-pixel so the image aspect-fills the screen at scale 1.
    func baseScale(in container: CGSize) -> CGFloat {
        guard pxW > 0, pxH > 0, container.width > 0, container.height > 0 else { return 1 }
        return max(container.width / pxW, container.height / pxH)
    }

    func displaySize(in container: CGSize) -> CGSize {
        let scaleFactor = baseScale(in: container)
        return CGSize(width: pxW * scaleFactor, height: pxH * scaleFactor)
    }

    /// Smallest zoom that still covers the crop frame (limiting side flush with
    /// the edge). Below 1 for a sub-screen frame; capped at 1 (never zooms in).
    func minScale(in container: CGSize, insets: EdgeInsets) -> CGFloat {
        let display = displaySize(in: container)
        guard display.width > 0, display.height > 0 else { return 1 }
        let frame = frameRect(in: container, insets: insets)
        let needed = max(frame.width / display.width, frame.height / display.height)
        return min(needed, 1)
    }

    /// Allowed offset range per axis so the image keeps the frame covered.
    func offsetBounds(scale: CGFloat, container: CGSize, insets: EdgeInsets)
        -> (x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>) {
        guard container.width > 0 else { return (0...0, 0...0) }
        let frame = frameRect(in: container, insets: insets)
        let display = displaySize(in: container)
        let deltaX = frame.midX - container.width / 2
        let deltaY = frame.midY - container.height / 2
        let limX = max(0, (display.width * scale - frame.width) / 2)
        let limY = max(0, (display.height * scale - frame.height) / 2)
        return ((deltaX - limX)...(deltaX + limX), (deltaY - limY)...(deltaY + limY))
    }

    func clampOffset(_ proposed: CGSize, scale: CGFloat, container: CGSize, insets: EdgeInsets) -> CGSize {
        let bounds = offsetBounds(scale: scale, container: container, insets: insets)
        return CGSize(
            width: min(max(proposed.width, bounds.x.lowerBound), bounds.x.upperBound),
            height: min(max(proposed.height, bounds.y.lowerBound), bounds.y.upperBound)
        )
    }

    /// Like `clampOffset`, but allows overscroll; the spring snaps it back.
    func rubberBandOffset(_ proposed: CGSize, scale: CGFloat, container: CGSize, insets: EdgeInsets) -> CGSize {
        let bounds = offsetBounds(scale: scale, container: container, insets: insets)
        return CGSize(
            width: rubberBand(proposed.width, lower: bounds.x.lowerBound, upper: bounds.x.upperBound, dimension: container.width),
            height: rubberBand(proposed.height, lower: bounds.y.lowerBound, upper: bounds.y.upperBound, dimension: container.height)
        )
    }

    /// Standard iOS rubber-band: linear within `[lower, upper]`, asymptotic past.
    func rubberBand(_ value: CGFloat, lower: CGFloat, upper: CGFloat, dimension: CGFloat) -> CGFloat {
        guard dimension > 0 else { return min(max(value, lower), upper) }
        if value < lower {
            let over = lower - value
            return lower - (1 - 1 / (over / dimension * 0.55 + 1)) * dimension
        } else if value > upper {
            let over = value - upper
            return upper + (1 - 1 / (over / dimension * 0.55 + 1)) * dimension
        }
        return value
    }

    /// Resists pinching below the frame-fill minimum or above `maxZoom`.
    func rubberBandedScale(_ proposed: CGFloat) -> CGFloat {
        let lower = minScale(in: containerSize, insets: safeInsets)
        if proposed < lower {
            return lower - (lower - proposed) * 0.35
        } else if proposed > maxZoom {
            return maxZoom + (proposed - maxZoom) * 0.35
        }
        return proposed
    }

    func cropImage() -> UIImage {
        guard containerSize.width > 0, let cgImage = source.cgImage else { return source }
        let pointsPerPixel = baseScale(in: containerSize) * scale
        guard pointsPerPixel > 0 else { return source }
        let frame = frameRect(in: containerSize, insets: safeInsets)
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)

        let cropW = frame.width / pointsPerPixel
        let cropH = frame.height / pointsPerPixel
        // Image is centred on screen at `offset`; the frame may sit off-centre.
        let centerX = CGFloat(cgImage.width) / 2 + (frame.midX - center.x - offset.width) / pointsPerPixel
        let centerY = CGFloat(cgImage.height) / 2 + (frame.midY - center.y - offset.height) / pointsPerPixel

        var rect = CGRect(x: centerX - cropW / 2, y: centerY - cropH / 2, width: cropW, height: cropH)
        rect.origin.x = min(max(0, rect.origin.x), CGFloat(cgImage.width) - rect.width)
        rect.origin.y = min(max(0, rect.origin.y), CGFloat(cgImage.height) - rect.height)
        rect = rect.integral

        guard let cropped = cgImage.cropping(to: rect) else { return source }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }
}

/// Applies the Liquid Glass button chrome, gated on availability. Prominent is
/// accent-filled (always legible); plain is regular glass.
private struct GlassButtonChrome: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            Group {
                if prominent {
                    content.buttonStyle(.glassProminent)
                } else {
                    content.buttonStyle(.glass)
                }
            }
            .buttonBorderShape(.circle)
            .tint(prominent ? Color.accentColor : nil)
        } else {
            content
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background {
                    if prominent {
                        Circle().fill(Color.accentColor)
                    } else {
                        // Dark underlay keeps the white glyph legible over photos.
                        ZStack {
                            Circle().fill(.black.opacity(0.25))
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                }
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
        }
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
