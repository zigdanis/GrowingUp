//
//  CameraCardView.swift
//  GrowingUp
//
//  The inline in-app camera card: a full-bleed live preview with shutter, flip,
//  flash (off / auto / on) and close controls. Close dismisses photo selection; a
//  capture is reported upward to feed the same crop step as the photo path.
//  An upright card keeps its controls along the bottom; a card wider than tall,
//  such as an iPad sheet on its side, keeps them in a column along the trailing edge.
//

import SwiftUI

struct CameraCardView: View {
	let controller: CameraSessionController
	/// A still shown and captured in place of the live preview, for UI tests on the Simulator, which has no camera.
	var standIn: UIImage?
	let onCapture: (UIImage) -> Void
	let onClose: () -> Void

	@State private var captureFailed = false

	var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()
			preview
				.ignoresSafeArea()
			GeometryReader { geometry in
				if geometry.size.width > geometry.size.height {
					landscapeControls
				} else {
					VStack {
						flashBar
						Spacer()
						controls
					}
				}
			}
		}
		.task {
			if standIn == nil { controller.start() }
		}
		.onDisappear {
			controller.stop()
		}
		.alert("Couldn't take photo", isPresented: $captureFailed) {
		} message: {
			Text("The photo couldn't be captured. Try again.")
		}
	}

	@ViewBuilder private var preview: some View {
		if let standIn {
			Image(uiImage: standIn)
				.resizable()
				.scaledToFill()
		} else {
			CameraPreview(session: controller.session, isMirrored: controller.isFront, onPreviewLayer: controller.attachPreview)
		}
	}

	/// The controls in a column along the trailing edge: flash at the top, the shutter in the middle with flip below it,
	/// and back in the bottom-leading corner.
	private var landscapeControls: some View {
		ZStack {
			VStack(spacing: 24) {
				// Balances flip below the shutter, so the shutter sits in the middle.
				Color.clear.frame(width: 64, height: 64)
				shutterButton
				flipButton
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
			flashButton
				.frame(width: 74)
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
			backButton
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
		}
		.padding(.horizontal, 32)
		.padding(.vertical, 28)
	}

	private var flashBar: some View {
		HStack {
			Spacer()
			flashButton
		}
		.padding(.horizontal, 20)
		.padding(.top, 8)
	}

	private var flashButton: some View {
		Button {
			controller.cycleFlash()
		} label: {
			Image(systemName: controller.flashMode.systemImage)
				.font(.title3.weight(.semibold))
				.foregroundStyle(.white)
				.padding(12)
				.background(.black.opacity(0.35), in: Circle())
		}
		.accessibilityLabel(Text("Flash"))
		.accessibilityValue(Text(flashAccessibilityValue))
	}

	private var controls: some View {
		HStack {
			backButton
			Spacer()
			shutterButton
			Spacer()
			flipButton
		}
		.padding(.horizontal, 32)
		.padding(.bottom, 28)
	}

	private var backButton: some View {
		Button(action: onClose) {
			Image(systemName: "chevron.left")
				.font(.title2.weight(.semibold))
				.foregroundStyle(.white)
				.frame(width: 64, height: 64)
				.background(.black.opacity(0.35), in: Circle())
		}
		.accessibilityLabel(Text("Close camera"))
		.accessibilityIdentifier("camera.back")
	}

	private var shutterButton: some View {
		Button(action: capture) {
			ZStack {
				Circle()
					.stroke(.white, lineWidth: 4)
					.frame(width: 74, height: 74)
				Circle()
					.fill(.white)
					.frame(width: 60, height: 60)
			}
		}
		.disabled(controller.isCapturing)
		.opacity(controller.isCapturing ? 0.5 : 1)
		.accessibilityLabel(Text("Take photo"))
	}

	@ViewBuilder private var flipButton: some View {
		if controller.canFlip {
			Button {
				controller.flip()
			} label: {
				Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
					.font(.title2.weight(.semibold))
					.foregroundStyle(.white)
					.frame(width: 64, height: 64)
					.background(.black.opacity(0.35), in: Circle())
			}
			.accessibilityLabel(Text("Flip camera"))
		} else {
			Color.clear.frame(width: 64, height: 64)
		}
	}

	private var flashAccessibilityValue: LocalizedStringKey {
		switch controller.flashMode {
		case .off: return "Off"
		case .auto: return "Auto"
		case .on: return "On"
		}
	}

	private func capture() {
		if let standIn {
			onCapture(standIn)
			return
		}
		controller.capturePhoto { image in
			if let image {
				onCapture(image)
			} else {
				captureFailed = true
			}
		}
	}
}
