//
//  CropStep.swift
//  GrowingUp
//
//  Pan/zoom cropper: image aspect-fills at min zoom; crop frame is full screen, or a centered portrait column in wider
//  windows (main), or a circular safe-area guide (widget). The math lives in `CropGeometry`.
//

import SwiftUI

struct CropStep: View {
	private let source: UIImage
	private let shape: CropShape
	private let onComplete: (UIImage) -> Void
	private let onCancel: () -> Void

	/// Source pixel dimensions, used to map the on-screen frame back to pixels.
	let pixelSize: CGSize

	@State private var scale: CGFloat = 1
	@State private var lastScale: CGFloat = 1
	@State private var offset: CGSize = .zero
	@State private var lastOffset: CGSize = .zero
	@State private var containerSize: CGSize = .zero
	@State private var safeInsets = EdgeInsets()
	@State private var isGesturing = false
	@State private var isFinishing = false

	/// `image` is upright: a `WorkingImage` or a picture the app stored. `onComplete` gets the framed part at the slot's
	/// stored size.
	init(
		image: UIImage,
		shape: CropShape,
		onComplete: @escaping (UIImage) -> Void,
		onCancel: @escaping () -> Void
	) {
		self.source = image
		self.shape = shape
		self.onComplete = onComplete
		self.onCancel = onCancel
		self.pixelSize = CropGeometry.pixelSize(of: image)
	}

	var body: some View {
		// `.ignoresSafeArea()` → `proxy.size` is the real screen (one coordinate space for image/clamp/crop); insets from the window.
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
		// A resized window (e.g. an iPhone Duo folding) can need more zoom to keep the circular frame covered.
		let geometry = geometry(in: full, insets: insets)
		let settledScale = geometry.clampScale(scale)
		let settled = geometry.clampOffset(offset, scale: settledScale)
		scale = settledScale
		lastScale = settledScale
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
		let display = geometry.displaySize
		return Image(uiImage: source)
			.resizable()
			.frame(width: display.width, height: display.height)
			.scaleEffect(scale)
			.offset(offset)
			// Pin the footprint to the screen, clip overflow (offset 0 == aspect-fill, which the clamp assumes).
			.frame(width: containerSize.width, height: containerSize.height)
			.clipped()
	}

	@ViewBuilder private var surround: some View {
		let frame = geometry.frameRect
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
		} else {
			ZStack {
				// A column narrower than the window gets the circle guide's mask and outline.
				if frame.width < containerSize.width {
					Path { path in
						path.addRect(CGRect(origin: .zero, size: containerSize))
						path.addRect(frame)
					}
					.fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
					Rectangle()
						.stroke(.white.opacity(0.9), lineWidth: 1)
						.frame(width: frame.width, height: frame.height)
						.position(x: frame.midX, y: frame.midY)
				}
				// A thirds guide while the picture moves.
				if isGesturing {
					ThirdsGrid()
						.stroke(.white.opacity(0.5), lineWidth: 0.5)
						.frame(width: frame.width, height: frame.height)
						.position(x: frame.midX, y: frame.midY)
				}
			}
			.allowsHitTesting(false)
		}
	}

	private func topBar(insets: EdgeInsets) -> some View {
		VStack {
			HStack {
				glassButton(systemImage: "xmark", prominent: false, action: onCancel)
					.accessibilityLabel(Text("Cancel"))
					.accessibilityIdentifier("crop.cancel")
				Spacer()
				glassButton(systemImage: "checkmark", prominent: true, action: finish)
					.accessibilityLabel(Text("Use photo"))
					.accessibilityIdentifier("crop.use")
			}
			.disabled(isFinishing)
			.padding(.horizontal, 20)
			.padding(.top, insets.top + 8)  // ZStack ignores the safe area; clear the notch manually.
			Spacer()
		}
	}

	/// Hands over the framed part once it is scaled down; both buttons wait meanwhile.
	private func finish() {
		isFinishing = true
		Task {
			onComplete(await output(container: containerSize, insets: safeInsets, scale: scale, offset: offset))
		}
	}

	/// A circular Liquid Glass icon button; `prominent` is the accent-filled affirmative (checkmark), plain glass is the X.
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
				offset = geometry.rubberBandOffset(raw, scale: scale)
			}
			.onEnded { _ in
				let settled = geometry.clampOffset(offset, scale: scale)
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
				let newScale = geometry.rubberBandedScale(lastScale * value.magnification)
				scale = newScale
				offset = geometry.rubberBandOffset(offset, scale: newScale)
			}
			.onEnded { _ in
				let settledScale = geometry.clampScale(scale)
				let settledOffset = geometry.clampOffset(offset, scale: settledScale)
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
	func geometry(in container: CGSize, insets: EdgeInsets) -> CropGeometry {
		CropGeometry(pixelSize: pixelSize, shape: shape, container: container, insets: insets)
	}

	/// The current canvas's geometry.
	var geometry: CropGeometry { geometry(in: containerSize, insets: safeInsets) }

	/// Smallest zoom that still covers the crop frame; see `CropGeometry.minScale`.
	func minScale(in container: CGSize, insets: EdgeInsets) -> CGFloat {
		geometry(in: container, insets: insets).minScale
	}

	/// The framed part at the slot's stored size.
	func output(container: CGSize, insets: EdgeInsets, scale: CGFloat, offset: CGSize) async -> UIImage {
		await geometry(in: container, insets: insets).output(of: source, scale: scale, offset: offset)
	}
}
