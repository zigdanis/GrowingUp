import UIKit

/// The columns and tile size of the people mosaic, chosen from the space it has.
///
/// Tiles keep the screen's 9:16 portrait shape, so a tile reads as a small copy of the full-screen viewer it opens.
struct MosaicGridLayout: Equatable {
	/// The gap between tiles and the margin at the mosaic's sides.
	static let spacing: CGFloat = 12
	/// The narrowest a tile gets by default before the mosaic adds a column; below two columns tiles narrow instead.
	static let minimumTileWidth: CGFloat = 160
	/// The fewest columns, so even the narrowest window, such as a 320 pt Slide Over, shows people side by side.
	static let minimumColumns = 2
	/// The widest a tile gets by default, so wide windows add columns instead of ever-larger tiles.
	static let maximumTileWidth: CGFloat = 240
	/// The tallest a tile gets as a share of the visible height, so a short window still shows a whole tile.
	static let maximumHeightShare: CGFloat = 0.8

	let columns: Int
	let tileWidth: CGFloat
	var tileHeight: CGFloat { tileWidth * 16 / 9 }
	/// The space above the first row: `spacing`, or more where the tiles sit centred in a window they fill.
	let topMargin: CGFloat

	/// The narrowest and widest tiles on `idiom`: an iPad's, seen from further away, stay larger, up to a few people
	/// filling its screen; its narrow windows still get the phone's two columns.
	static func tileWidths(idiom: UIUserInterfaceIdiom) -> ClosedRange<CGFloat> {
		idiom == .pad ? 200...400 : minimumTileWidth...maximumTileWidth
	}

	/// - Parameters:
	///   - size: the space the mosaic scrolls in.
	///   - count: how many people it shows; fewer people than columns get only as many columns, centred, so one
	///     person is a single centred tile rather than a tile beside an empty hole.
	///   - evenColumns: keeps an even number of columns, so the gap between the middle columns, not a tile, sits on
	///     the window's centre, where a landscape iPhone Duo folds; an odd number of people leaves the last column's
	///     slot empty rather than putting a tile on the fold.
	///   - minimumTileWidth: the narrowest a tile gets before the mosaic adds a column.
	///   - maximumTileWidth: the widest a tile gets.
	///   - fillsWindow: lets few enough people to fit at `minimumTileWidth` or wider fill the window, as on iPad: the
	///     columns that give the largest tiles, all in view and centred in it; more people scroll as usual.
	init(
		size: CGSize, count: Int, evenColumns: Bool = false, minimumTileWidth: CGFloat = Self.minimumTileWidth,
		maximumTileWidth: CGFloat = Self.maximumTileWidth, fillsWindow: Bool = false
	) {
		let width = max(0, size.width - 2 * Self.spacing)
		let heightLimit = size.height * Self.maximumHeightShare * 9 / 16
		let widest = max(1, min(maximumTileWidth, heightLimit))
		let narrowest = min(minimumTileWidth, widest)
		var fitting = max(Self.minimumColumns, Int((width + Self.spacing) / (narrowest + Self.spacing)))
		if evenColumns, fitting > 1 { fitting -= fitting % 2 }
		let area = CGSize(width: width, height: max(0, size.height - 2 * Self.spacing))
		if fillsWindow,
			let fit = Self.largestFit(
				in: area, count: count, fitting: fitting, evenColumns: evenColumns, maximumTileWidth: maximumTileWidth),
			fit.width >= minimumTileWidth
		{
			let rows = CGFloat((count + fit.columns - 1) / fit.columns)
			columns = fit.columns
			tileWidth = fit.width
			topMargin = Self.spacing + (area.height - rows * fit.width * 16 / 9 - (rows - 1) * Self.spacing) / 2
			return
		}
		let wanted = evenColumns ? count + count % 2 : count
		let columns = max(1, min(fitting, wanted))
		let filled = (width - CGFloat(fitting - 1) * Self.spacing) / CGFloat(fitting)
		self.columns = columns
		tileWidth = max(0, min(widest, filled))
		topMargin = Self.spacing
	}

	/// The number of columns, up to `fitting` and even with `evenColumns`, that shows `count` people at the largest tile
	/// with every row inside `area`, and that tile's width; a strict tie goes to fewer columns. Two or more people get at
	/// least `minimumColumns`, as everywhere else in the mosaic; only one person may fill a single column.
	private static func largestFit(
		in area: CGSize, count: Int, fitting: Int, evenColumns: Bool, maximumTileWidth: CGFloat
	) -> (columns: Int, width: CGFloat)? {
		guard count > 0, area.width > 0, area.height > 0 else { return nil }
		var best: (columns: Int, width: CGFloat)?
		let fewest = count < minimumColumns ? 1 : minimumColumns
		guard fitting >= fewest else { return nil }
		for columns in fewest...fitting where !evenColumns || columns % 2 == 0 {
			let rows = (count + columns - 1) / columns
			let byWidth = (area.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
			let byHeight = (area.height - CGFloat(rows - 1) * spacing) / CGFloat(rows) * 9 / 16
			let width = min(maximumTileWidth, byWidth, byHeight)
			if width > (best?.width ?? 0) { best = (columns, width) }
		}
		return best
	}

	// MARK: - Slots

	/// The top-leading corner of the tile in slot `index` of the mosaic's scroll content, `width` wide: the columns sit
	/// centred, below `topMargin`.
	func origin(ofSlot index: Int, width: CGFloat) -> CGPoint {
		CGPoint(
			x: leadingMargin(width: width) + CGFloat(index % columns) * (tileWidth + Self.spacing),
			y: topMargin + CGFloat(index / columns) * (tileHeight + Self.spacing))
	}

	/// The slot of `count` tiles whose cell, the tile with half the gap around it, holds `point` of the scroll content,
	/// `width` wide; a point beyond the tiles takes the nearest one, and past the last tile the last slot.
	func slot(at point: CGPoint, count: Int, width: CGFloat) -> Int {
		let cellX = (point.x - leadingMargin(width: width) + Self.spacing / 2) / (tileWidth + Self.spacing)
		let cellY = (point.y - topMargin + Self.spacing / 2) / (tileHeight + Self.spacing)
		let column = min(max(Int(cellX.rounded(.down)), 0), columns - 1)
		let row = max(Int(cellY.rounded(.down)), 0)
		return max(0, min(row * columns + column, count - 1))
	}

	/// The slot of `count` tiles whose tile, its corners rounded by `cornerRadius`, holds `point` of the scroll content,
	/// `width` wide; nil for a point in the margins, the gaps, an empty slot, below the last row or in a tile's cut-off
	/// corner.
	func slot(ofTileAt point: CGPoint, count: Int, width: CGFloat, cornerRadius: CGFloat) -> Int? {
		guard count > 0 else { return nil }
		let slot = slot(at: point, count: count, width: width)
		let tile = CGRect(origin: origin(ofSlot: slot, width: width), size: CGSize(width: tileWidth, height: tileHeight))
		guard tile.contains(point) else { return nil }
		// How far the point lies beyond the square inset of each corner, which only a corner's own quadrant can be.
		let radius = min(cornerRadius, tileWidth / 2, tileHeight / 2)
		let beyondX = max(tile.minX + radius - point.x, point.x - tile.maxX + radius, 0)
		let beyondY = max(tile.minY + radius - point.y, point.y - tile.maxY + radius, 0)
		return beyondX * beyondX + beyondY * beyondY <= radius * radius ? slot : nil
	}

	private func leadingMargin(width: CGFloat) -> CGFloat {
		(width - CGFloat(columns) * tileWidth - CGFloat(columns - 1) * Self.spacing) / 2
	}
}
