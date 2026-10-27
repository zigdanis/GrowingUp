import SwiftUI

/// The edit mode's photo, filling the window exactly as the viewer's page does until a pinch zooms it or a drag moves it.
/// It is the whole original the main picture was framed from, so zooming out or moving reaches parts the picture left
/// out. The thirds grid over the crop frame shows that the gestures now belong to the photo; double-tapping puts it back.
/// Without a main photo it shows what the person's page shows: their widget picture, which stays as it is, or else
/// their monogram.
struct EditModePhoto: View {
	let mode: PersonEditModePresenter
	let window: CGSize

	var body: some View {
		ZStack {
			if let photo = mode.photo, let geometry = mode.geometry(of: photo) {
				Color.black
				framed(photo, geometry: geometry)
					// One element the size of the window, which stays put however far the photo is zoomed or moved.
					.accessibilityElement(children: .ignore)
					.accessibilityAddTraits(.isImage)
					.accessibilityLabel(Text("Selected photo"))
					// The zoom, where 100% shows as much of the photo as the screen holds.
					.accessibilityValue(Text(Double(mode.framing.scale), format: .percent.precision(.fractionLength(0))))
					.accessibilityIdentifier("editor.appPhoto.loaded")
				guides(geometry.frameRect)
					.accessibilityHidden(true)
				surface
			} else if let backdrop = mode.backdrop {
				filling(backdrop)
			} else if mode.showsMonogram, let person = mode.editor.person {
				// The monogram the person's tile and page show without a photo, taking the edited name's initial.
				PersonMonogram(id: person.id, name: mode.editor.name)
			}
			// While a saved photo loads, the viewer's page shows through, so the switch into edit mode never flashes; a new
			// person's draft lies on the cover's glow, as it gets its own monogram colour only once added.
		}
		.frame(width: window.width, height: window.height)
		// Touches anywhere on it stay in edit mode, never reaching the viewer's page beneath, even before a photo loads.
		.contentShape(Rectangle())
	}

	/// Moves, zooms and, on a double tap, puts back the photo; every gesture that starts on it while editing is its own.
	private var surface: some View {
		let settle = Animation.spring(response: 0.35, dampingFraction: 0.82)
		return FramingSurface(
			onDrag: { mode.drag(by: $0) },
			onDragEnd: { withAnimation(settle) { mode.endDrag() } },
			onPinch: { mode.magnify(by: $0) },
			onPinchEnd: { withAnimation(settle) { mode.endMagnify() } },
			onDoubleTap: { withAnimation(settle) { mode.resetFraming() } }
		)
		.accessibilityHidden(true)
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

	/// The widget picture filling the window as the viewer's page fills it; the gestures leave it as it is.
	private func filling(_ picture: UIImage) -> some View {
		Image(uiImage: picture)
			.resizable()
			.scaledToFill()
			.frame(width: window.width, height: window.height)
			.clipped()
			.accessibilityHidden(true)
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
}
