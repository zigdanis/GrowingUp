import Core
import SwiftUI

/// The home screen's grid of people tiles in mosaic order; a tile opens that person full screen, zooming out of it.
///
/// A long press on a tile starts reordering: the tile lifts and follows the finger, its neighbours make room live, and
/// the mosaic scrolls when the finger nears its top or bottom edge.
struct PeopleMosaic: View {
	private static let contentSpace = NamedCoordinateSpace.named("mosaic.content")

	let persons: [Person]
	let pictures: MosaicPicturesPresenter
	/// The person to keep in view: the one the viewer shows, so it closes into a visible tile, or a newly added one.
	let selectedID: UUID?
	/// Gives the mosaic an even number of columns, so no tile straddles the fold of a landscape iPhone Duo.
	let evenColumns: Bool
	let isReordering: Bool
	let zoom: Namespace.ID
	let now: () -> Date
	let onOpen: (UUID) -> Void
	let onStartReordering: () -> Void
	let onFinishReordering: () -> Void
	/// Moves a person to an index of the mosaic while reordering.
	let onMove: (UUID, Int) -> Void
	/// Stores the mosaic's order once a moved tile lands.
	let onSaveOrder: () async -> Void

	@State private var drag: MosaicDrag?
	@State private var autoscroll: MosaicAutoscroll?
	@State private var position = ScrollPosition(idType: UUID.self)
	/// -1 or 1 while a dragged tile is near the top or bottom edge, which scrolls the mosaic that way; otherwise 0.
	@State private var autoscrollDirection = 0

	var body: some View {
		GeometryReader { geometry in
			let grid = MosaicGridLayout(size: geometry.size, count: persons.count, evenColumns: evenColumns)
			let width = geometry.size.width
			ScrollViewReader { proxy in
				ScrollView {
					LazyVGrid(
						columns: Array(repeating: GridItem(.fixed(grid.tileWidth), spacing: MosaicGridLayout.spacing), count: grid.columns),
						spacing: MosaicGridLayout.spacing
					) {
						ForEach(persons, id: \.id) { person in
							tile(person, grid: grid, width: width)
								.frame(width: grid.tileWidth, height: grid.tileHeight)
								.id(person.id)
						}
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, MosaicGridLayout.spacing)
					// Fills the visible mosaic, so a tap beside or below the tiles finishes reordering.
					.frame(minHeight: geometry.size.height, alignment: .top)
					.overlay { if isReordering { gaps(grid: grid) } }
					.overlay(alignment: .topLeading) { floatingTile(grid: grid, width: width) }
					.coordinateSpace(Self.contentSpace)
				}
				.scrollIndicators(.hidden)
				.scrollPosition($position)
				// The finger carries the dragged tile, so it must not scroll the mosaic too; the edges scroll it instead.
				.scrollDisabled(drag != nil)
				.onScrollGeometryChange(
					for: ScrollGeometry.self, of: { $0 },
					action: { old, new in
						autoscroll = MosaicAutoscroll(new)
						// The content slid under a still finger, so the finger now points further along it.
						guard var moved = drag, let location = moved.location else { return }
						moved.location = CGPoint(x: location.x, y: location.y + new.contentOffset.y - old.contentOffset.y)
						drag = moved
						followDrag(grid: grid, width: width)
					}
				)
				.onChange(of: selectedID) { _, id in
					guard let id else { return }
					withAnimation { proxy.scrollTo(id, anchor: .center) }
				}
				.task(id: autoscrollDirection) {
					await autoscrollWhileNearAnEdge()
				}
			}
		}
		.sensoryFeedback(.impact(weight: .medium), trigger: drag?.id) { _, id in id != nil }
	}

	private func tile(_ person: Person, grid: MosaicGridLayout, width: CGFloat) -> some View {
		let index = persons.firstIndex { $0.id == person.id } ?? 0
		return MosaicTileButton(
			person: person, picture: pictures.picture(for: person)?.image, now: now, isReordering: isReordering,
			isLifted: drag?.id == person.id, zoom: zoom, contentSpace: Self.contentSpace,
			onOpen: { onOpen(person.id) },
			onLift: { lift(person.id) },
			onDrag: { value in
				guard drag?.id == person.id, let index = persons.firstIndex(where: { $0.id == person.id }) else { return }
				drag?.follow(to: value.location, from: value.startLocation, slotOrigin: grid.origin(ofSlot: index, width: width))
				followDrag(grid: grid, width: width)
			},
			onDrop: { drop(person.id) },
			onStartReordering: onStartReordering,
			onMoveEarlier: index > 0 ? { moveByAccessibility(person.id, to: index - 1) } : nil,
			onMoveLater: index < persons.count - 1 ? { moveByAccessibility(person.id, to: index + 1) } : nil)
	}

	/// The space beside and below the tiles, where a tap finishes reordering; it lies over the tiles, as their touch areas
	/// reach into the gaps and would take the tap first.
	private func gaps(grid: MosaicGridLayout) -> some View {
		Color.clear
			.contentShape(MosaicGaps(grid: grid, count: persons.count), eoFill: true)
			.onTapGesture(perform: onFinishReordering)
	}

	/// The lifted tile above the mosaic, under the finger, a little larger and higher than its neighbours.
	@ViewBuilder
	private func floatingTile(grid: MosaicGridLayout, width: CGFloat) -> some View {
		if let drag, let index = persons.firstIndex(where: { $0.id == drag.id }) {
			let origin = drag.origin(slotOrigin: grid.origin(ofSlot: index, width: width))
			MosaicTile(person: persons[index], picture: pictures.picture(for: persons[index])?.image, now: now)
				.frame(width: grid.tileWidth, height: grid.tileHeight)
				.scaleEffect(drag.isSettling ? 1 : 1.06)
				.shadow(color: .black.opacity(drag.isSettling ? 0 : 0.3), radius: 24, y: 16)
				.offset(x: origin.x, y: origin.y)
				.allowsHitTesting(false)
				.accessibilityHidden(true)
		}
	}

	// MARK: - Dragging

	private func lift(_ id: UUID) {
		// A tile still gliding into its slot lands at once, so the next one can lift.
		if drag?.isSettling == true { drag = nil }
		guard drag == nil else { return }
		onStartReordering()
		withAnimation(.snappy(duration: 0.2)) { drag = MosaicDrag(id: id) }
	}

	/// Moves the dragged person to the slot under the floating tile's centre, and scrolls when it nears an edge.
	private func followDrag(grid: MosaicGridLayout, width: CGFloat) {
		guard let drag, !drag.isSettling, drag.location != nil,
			let index = persons.firstIndex(where: { $0.id == drag.id })
		else { return }
		let origin = drag.origin(slotOrigin: grid.origin(ofSlot: index, width: width))
		let centre = CGPoint(x: origin.x + grid.tileWidth / 2, y: origin.y + grid.tileHeight / 2)
		let slot = grid.slot(at: centre, count: persons.count, width: width)
		if slot != index {
			withAnimation(.snappy(duration: 0.25)) { onMove(drag.id, slot) }
		}
		autoscrollDirection = drag.location.flatMap { autoscroll?.direction(at: $0) } ?? 0
	}

	private func drop(_ id: UUID) {
		guard drag?.id == id, drag?.isSettling == false else { return }
		autoscrollDirection = 0
		withAnimation(.snappy(duration: 0.25)) {
			drag?.isSettling = true
		} completion: {
			if drag?.id == id, drag?.isSettling == true { drag = nil }
		}
		Task { await onSaveOrder() }
	}

	private func moveByAccessibility(_ id: UUID, to index: Int) {
		onMove(id, index)
		Task { await onSaveOrder() }
	}

	// MARK: - Autoscroll

	/// Scrolls the mosaic a frame at a time while the dragged tile is near an edge, faster the closer the finger is.
	///
	/// It waits a moment first, so a tile dropped near an edge lands where it was dropped.
	private func autoscrollWhileNearAnEdge() async {
		guard autoscrollDirection != 0 else { return }
		try? await Task.sleep(for: MosaicAutoscroll.delay)
		var last = Date()
		while !Task.isCancelled {
			try? await Task.sleep(for: .milliseconds(16))
			let now = Date()
			defer { last = now }
			guard let autoscroll, let location = drag?.location,
				let next = autoscroll.position(after: now.timeIntervalSince(last), location: location)
			else { continue }
			position.scrollTo(y: next)
		}
	}
}
