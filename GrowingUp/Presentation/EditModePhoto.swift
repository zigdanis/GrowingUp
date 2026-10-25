import SwiftUI

/// The edit mode's photo, filling the window exactly as the viewer's page does until a pinch zooms it or a drag moves it.
/// The thirds grid over the crop frame shows that the gestures now belong to the photo; double-tapping puts it back.
/// Without a photo it shows the person's monogram, as their page does.
struct EditModePhoto: View {
	let mode: PersonEditModePresenter
	let window: CGSize

	var body: some View {
		ZStack {
			if let photo = mode.photo, let geometry = mode.geometry(of: photo) {
				Color.black
				framed(photo, geometry: geometry)
					.accessibilityLabel(Text("Selected photo"))
					.accessibilityIdentifier("editor.appPhoto.loaded")
				guides(geometry.frameRect)
					.accessibilityHidden(true)
			} else if mode.editor.appImage == nil, let person = mode.editor.person {
				// The monogram the person's tile and page show without a photo, taking the edited name's initial.
				PersonMonogram(id: person.id, name: mode.editor.name)
			}
			// While a saved photo loads, the viewer's page shows through, so the switch into edit mode never flashes; a new
			// person's draft lies on the cover's glow, as it gets its own monogram colour only once added.
		}
		.frame(width: window.width, height: window.height)
		.contentShape(Rectangle())
		.simultaneousGesture(dragGesture)
		.simultaneousGesture(magnifyGesture)
		.onTapGesture(count: 2) {
			withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { mode.resetFraming() }
		}
	}

	private func framed(_ photo: UIImage, geometry: CropGeometry) -> some View {
		let display = geometry.displaySize
		return Image(uiImage: photo)
			.resizable()
			.frame(width: display.width, height: display.height)
			.scaleEffect(mode.framing.scale)
			.offset(mode.framing.offset)
			// Offset zero is the aspect-fill the viewer shows, which the clamp assumes.
			.frame(width: window.width, height: window.height)
			.clipped()
	}

	private func guides(_ frame: CGRect) -> some View {
		ZStack {
			// In a window wider than a portrait photo, the column outside the frame is dimmed, as in `CropStep`.
			if frame.width < window.width {
				Path { path in
					path.addRect(CGRect(origin: .zero, size: window))
					path.addRect(frame)
				}
				.fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
			}
			ThirdsGrid()
				.stroke(.white.opacity(mode.isFraming ? 0.6 : 0.32), lineWidth: 1)
				.frame(width: frame.width, height: frame.height)
				.position(x: frame.midX, y: frame.midY)
		}
		.allowsHitTesting(false)
	}

	private var dragGesture: some Gesture {
		DragGesture()
			.onChanged { mode.drag(by: $0.translation) }
			.onEnded { _ in
				withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { mode.endDrag() }
			}
	}

	private var magnifyGesture: some Gesture {
		MagnifyGesture()
			.onChanged { mode.magnify(by: $0.magnification) }
			.onEnded { _ in
				withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { mode.endMagnify() }
			}
	}
}
