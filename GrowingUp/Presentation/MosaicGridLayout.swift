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
}
