import Core
import SwiftUI

/// A mosaic tile as a control: a tap opens the person, and a long press lifts the tile to reorder the mosaic, carrying on
/// into a drag without letting go. A swipe that starts on the tile scrolls the mosaic; see `MosaicLiftGesture`.
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
	/// Follows the finger carrying the lifted tile, at this point of the mosaic's scroll content.
	let onDrag: (CGPoint) -> Void
	let onDrop: () -> Void
	/// Starts reordering without the long press, for accessibility.
	let onStartReordering: () -> Void
	/// Moves the tile a place earlier or later and stores the order; nil at that end of the mosaic.
	let onMoveEarlier: (() -> Void)?
	let onMoveLater: (() -> Void)?

	var body: some View {
		Button(action: onOpen) {
			MosaicTile(person: person, picture: picture, now: now)
				.modifier(MosaicWiggle(isActive: isReordering && !isLifted, seed: person.id.hashValue))
				.opacity(isLifted ? 0 : 1)
				// The empty slot keeps the lifted tile's press alive under the finger.
				.contentShape(.rect(cornerRadius: MosaicTile.cornerRadius))
				// The UIKit delegate lets the button and hold recognize together on iOS 18. A recognized hold enters
				// reordering before release, so the button action cannot open a person; movement still fails the hold.
				.gesture(
					MosaicLiftGesture(
						minimumDuration: Self.liftDelay, coordinateSpace: contentSpace,
						onLift: { location in
							onLift()
							onDrag(location)
						}, onMove: onDrag, onRelease: onDrop))
		}
		.buttonStyle(.plain)
		// A pointer, as on iPad with a trackpad, lifts the tile it rests on.
		.contentShape(.hoverEffect, .rect(cornerRadius: MosaicTile.cornerRadius))
		.hoverEffect(.lift)
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
}
