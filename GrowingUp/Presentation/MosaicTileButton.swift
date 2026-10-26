import Core
import SwiftUI

/// A mosaic tile as a control: a tap opens the person, and a long press lifts the tile to reorder the mosaic, carrying on
/// into a drag without letting go.
///
/// The long press is the only gesture into reordering, with no context menu; VoiceOver has a "Reorder" action instead.
/// While reordering the tile rocks. VoiceOver's "Move earlier" and "Move later" move it a place along at any time, as
/// they need no dragging.
struct MosaicTileButton: View {
	/// How long a press waits before it lifts the tile, a little shorter than a context menu's.
	static let liftDelay: TimeInterval = 0.4

	let person: Person
	let picture: UIImage?
	let now: () -> Date
	let isReordering: Bool
	/// Whether the tile's floating copy is above the mosaic, which leaves the tile's own slot empty.
	let isLifted: Bool
	let zoom: Namespace.ID
	/// The coordinate space of the mosaic's scroll content that drags report in.
	let contentSpace: NamedCoordinateSpace
	let onOpen: () -> Void
	let onLift: () -> Void
	let onDrag: (DragGesture.Value) -> Void
	let onDrop: () -> Void
	/// Starts reordering without the long press, for accessibility.
	let onStartReordering: () -> Void
	/// Moves the tile a place earlier or later and stores the order; nil at that end of the mosaic.
	let onMoveEarlier: (() -> Void)?
	let onMoveLater: (() -> Void)?
	/// Whether a press lifted the tile and has not ended; the system resets it when it cancels the press too.
	@GestureState private var isHeld = false

	var body: some View {
		Button(action: onOpen) {
			MosaicTile(person: person, picture: picture, now: now)
				.modifier(MosaicWiggle(isActive: isReordering && !isLifted, seed: person.id.hashValue))
				.opacity(isLifted ? 0 : 1)
				// The empty slot keeps the lifted tile's press alive under the finger.
				.contentShape(.rect(cornerRadius: MosaicTile.cornerRadius))
		}
		.buttonStyle(.plain)
		.simultaneousGesture(reorderGesture)
		.onChange(of: isHeld) { _, held in
			if !held { onDrop() }
		}
		// Optional, like the viewer's selection it is matched against.
		.matchedTransitionSource(id: Optional(person.id), in: zoom) { source in
			source.clipShape(.rect(cornerRadius: MosaicTile.cornerRadius))
		}
		.accessibilityActions {
			if !isReordering {
				Button("Reorder", action: onStartReordering)
			}
			if let onMoveEarlier {
				Button("Move earlier", action: onMoveEarlier)
			}
			if let onMoveLater {
				Button("Move later", action: onMoveLater)
			}
		}
		.accessibilityIdentifier("people.tile")
	}

	/// A long press that lifts the tile, then a drag from the same touch that carries it.
	private var reorderGesture: some Gesture {
		LongPressGesture(minimumDuration: Self.liftDelay)
			.sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: contentSpace))
			.updating($isHeld) { value, state, _ in
				if case .second(true, _) = value { state = true }
			}
			.onChanged { value in
				guard case .second(true, let drag) = value else { return }
				onLift()
				if let drag { onDrag(drag) }
			}
			.onEnded { _ in onDrop() }
	}
}
