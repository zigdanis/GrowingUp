//
//  CropStep.swift
//  GrowingUp
//
//  Pan/zoom cropper: image aspect-fills at min zoom; crop frame is full screen, or a centered portrait column in wider
//  windows (main), or a circular safe-area guide (widget). It opens on the region framed before, if any. The math lives
//  in `CropGeometry`.
//

import Core
import SwiftUI

struct CropStep: View {
	private let source: UIImage
	private let shape: CropShape
	/// The region framed before, which the picture opens on; nil opens it aspect-filling the screen.
	private let initialCrop: PhotoCrop?
	private let onComplete: (FramedPhoto) -> Void
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
	/// Whether the picture took its first place on a laid-out screen, on `initialCrop`.
	@State private var isPlaced = false

	/// `image` is upright: a `WorkingImage` or an original the app stored. `onComplete` gets the framed region with the
	/// picture rendered from it at the slot's stored size.
	init(
		image: UIImage,
		shape: CropShape,
		initialCrop: PhotoCrop? = nil,
		onComplete: @escaping (FramedPhoto) -> Void,
		onCancel: @escaping () -> Void
	) {
		self.source = image
		self.shape = shape
		self.initialCrop = initialCrop
		self.onComplete = onComplete
		self.onCancel = onCancel
		self.pixelSize = CropGeometry.pixelSize(of: image)
	}

	var body: some View {
		// The outer reader keeps the safe area: its insets are the real, current ones, for the circle frame and the toolbar.
		GeometryReader { safeArea in
			ZStack {
				// `.ignoresSafeArea()` → `proxy.size` is the real screen (one coordinate space for image/clamp/crop).
				GeometryReader { proxy in
					cropContent
						.contentShape(Rectangle())
						.simultaneousGesture(dragGesture)
						.simultaneousGesture(zoomGesture)
						.accessibilityElement(children: .ignore)
						.accessibilityLabel(Text("Selected photo"))
						.accessibilityValue(Text(Double(scale), format: .percent.precision(.fractionLength(0))))
						.accessibilityIdentifier("crop.photo")
						.onAppear { updateContainer(proxy.size, insets: safeArea.safeAreaInsets) }
						.onChange(of: proxy.size) { _, size in updateContainer(size, insets: safeArea.safeAreaInsets) }
				}
				.ignoresSafeArea()
				// Turning a window between landscape sides swaps the insets and keeps the size.
				.onChange(of: safeArea.safeAreaInsets) { _, insets in updateContainer(containerSize, insets: insets) }
				// Laid out inside the safe area, so a notch, camera or status column never covers the buttons.
				topBar
			}
		}
		.statusBarHidden()
		#if DEBUG
			.safeAreaPadding(.horizontal, uiTestSideSafeArea)
		#endif
	}

	#if DEBUG
		/// Exercise camera-sized side exclusions even on a portrait-only CI device.
		private var uiTestSideSafeArea: CGFloat {
			guard case .uiTest = AppLaunchMode.current,
				ProcessInfo.processInfo.environment["GROWINGUP_CROP_SIDE_SAFE_AREA"] == "1"
			else { return 0 }
			return 80
		}
	#endif

	/// Capture the true screen size plus the safe-area insets, then re-settle.
	private func updateContainer(_ full: CGSize, insets: EdgeInsets) {
		containerSize = full
		safeInsets = insets
		let geometry = geometry(in: full, insets: insets)
		// The first layout opens on the region framed before.
		if !isPlaced, full.width > 0, full.height > 0 {
			isPlaced = true
			if let initialCrop {
				let framing = geometry.framing(showing: initialCrop)
				scale = framing.scale
				offset = framing.offset
			}
		}
		// A resized window (e.g. an iPhone Duo folding) can need more zoom to keep the circular frame covered.
		let settledScale = geometry.clampScale(scale)
		let settled = geometry.clampOffset(offset, scale: settledScale)
		scale = settledScale
		lastScale = settledScale
		offset = settled
		lastOffset = settled
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

	private var topBar: some View {
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
			.padding(.top, 8)
			Spacer()
		}
		.background { safeAreaMarker }
	}

	/// The safe area as UI tests see it, to check the toolbar against.
	@ViewBuilder private var safeAreaMarker: some View {
		#if DEBUG
			if case .uiTest = AppLaunchMode.current {
				Color.clear
					.allowsHitTesting(false)
					.accessibilityElement(children: .ignore)
					.accessibilityLabel(Text(verbatim: "Safe area"))
					.accessibilityIdentifier("crop.safeArea")
			}
		#endif
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
		CropGeometry(pixelSize: pixelSize, shape: shape, container: container, insets: insets, idiom: UIDevice.current.userInterfaceIdiom)
	}

	/// The current canvas's geometry.
	var geometry: CropGeometry { geometry(in: containerSize, insets: safeInsets) }

	/// Smallest zoom that still covers the crop frame; see `CropGeometry.minScale`.
	func minScale(in container: CGSize, insets: EdgeInsets) -> CGFloat {
		geometry(in: container, insets: insets).minScale
	}

	/// The framed region, with the picture rendered from it at the slot's stored size.
	func output(container: CGSize, insets: EdgeInsets, scale: CGFloat, offset: CGSize) async -> FramedPhoto {
		await geometry(in: container, insets: insets).output(of: source, scale: scale, offset: offset)
	}
}
