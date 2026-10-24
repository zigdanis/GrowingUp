import CoreGraphics

/// The columns and tile size of the people mosaic, chosen from the space it has.
///
/// Tiles keep the screen's 9:16 portrait shape, so a tile reads as a small copy of the full-screen viewer it opens.
struct MosaicGridLayout: Equatable {
	/// The gap between tiles and the margin at the mosaic's sides.
	static let spacing: CGFloat = 12
	/// The narrowest a tile gets before the mosaic adds a column; below two columns tiles narrow instead.
	static let minimumTileWidth: CGFloat = 160
	/// The fewest columns, so even the narrowest window, such as a 320 pt Slide Over, shows people side by side.
	static let minimumColumns = 2
	/// The widest a tile gets, so wide windows add columns instead of ever-larger tiles.
	static let maximumTileWidth: CGFloat = 240
	/// The tallest a tile gets as a share of the visible height, so a short window still shows a whole tile.
	static let maximumHeightShare: CGFloat = 0.8

	let columns: Int
	let tileWidth: CGFloat
	var tileHeight: CGFloat { tileWidth * 16 / 9 }

	/// - Parameters:
	///   - size: the space the mosaic scrolls in.
	///   - count: how many people it shows; fewer people than columns get only as many columns, centred, so one
	///     person is a single centred tile rather than a tile beside an empty hole.
	///   - evenColumns: keeps an even number of columns, so the gap between the middle columns, not a tile, sits on
	///     the window's centre, where a landscape iPhone Duo folds; an odd number of people leaves the last column's
	///     slot empty rather than putting a tile on the fold.
	init(size: CGSize, count: Int, evenColumns: Bool = false) {
		let width = max(0, size.width - 2 * Self.spacing)
		let heightLimit = size.height * Self.maximumHeightShare * 9 / 16
		let widest = max(1, min(Self.maximumTileWidth, heightLimit))
		let narrowest = min(Self.minimumTileWidth, widest)
		var fitting = max(Self.minimumColumns, Int((width + Self.spacing) / (narrowest + Self.spacing)))
		if evenColumns, fitting > 1 { fitting -= fitting % 2 }
		let wanted = evenColumns ? count + count % 2 : count
		let columns = max(1, min(fitting, wanted))
		let filled = (width - CGFloat(fitting - 1) * Self.spacing) / CGFloat(fitting)
		self.columns = columns
		tileWidth = max(0, min(widest, filled))
	}

	// MARK: - Slots

	/// The top-leading corner of the tile in slot `index` of the mosaic's scroll content, `width` wide: the columns sit
	/// centred, below a `spacing` margin.
	func origin(ofSlot index: Int, width: CGFloat) -> CGPoint {
		CGPoint(
			x: leadingMargin(width: width) + CGFloat(index % columns) * (tileWidth + Self.spacing),
			y: Self.spacing + CGFloat(index / columns) * (tileHeight + Self.spacing))
	}

	/// The slot of `count` tiles whose cell, the tile with half the gap around it, holds `point` of the scroll content,
	/// `width` wide; a point beyond the tiles takes the nearest one, and past the last tile the last slot.
	func slot(at point: CGPoint, count: Int, width: CGFloat) -> Int {
		let cellX = (point.x - leadingMargin(width: width) + Self.spacing / 2) / (tileWidth + Self.spacing)
		let cellY = (point.y - Self.spacing / 2) / (tileHeight + Self.spacing)
		let column = min(max(Int(cellX.rounded(.down)), 0), columns - 1)
		let row = max(Int(cellY.rounded(.down)), 0)
		return max(0, min(row * columns + column, count - 1))
	}

	private func leadingMargin(width: CGFloat) -> CGFloat {
		(width - CGFloat(columns) * tileWidth - CGFloat(columns - 1) * Self.spacing) / 2
	}
}
