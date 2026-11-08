import CoreGraphics

extension MosaicGridLayout {
	/// The width of the tiles' columns and the gaps between them.
	var contentWidth: CGFloat {
		CGFloat(columns) * tileWidth + CGFloat(max(columns - 1, 0)) * Self.spacing
	}

	/// The grid of `count` people followed by the widget hint, and where the hint goes.
	///
	/// The hint counts as one more tile: the grid is laid out for `count + 1`, and when that leaves the slot after the
	/// last person in a row of its own people, the hint is a card in that slot. One person thus stands beside it rather
	/// than alone in the middle, and three on a two-column iPhone fill their last row with it. When the people fill
	/// their last row, the hint is a row of its own under the grid of the people alone, which leaves the tiles exactly
	/// where they are without it.
	///
	/// The other parameters are those of `init(size:count:evenColumns:minimumTileWidth:maximumTileWidth:fillsWindow:)`.
	static func withWidgetHint(
		size: CGSize, count: Int, evenColumns: Bool = false, minimumTileWidth: CGFloat = Self.minimumTileWidth,
		maximumTileWidth: CGFloat = Self.maximumTileWidth, fillsWindow: Bool = false
	) -> (grid: MosaicGridLayout, hint: WidgetHintPlacement) {
		let withHint = MosaicGridLayout(
			size: size, count: count + 1, evenColumns: evenColumns, minimumTileWidth: minimumTileWidth,
			maximumTileWidth: maximumTileWidth, fillsWindow: fillsWindow)
		if count % withHint.columns != 0 { return (withHint, .slot(count)) }
		let peopleOnly = MosaicGridLayout(
			size: size, count: count, evenColumns: evenColumns, minimumTileWidth: minimumTileWidth,
			maximumTileWidth: maximumTileWidth, fillsWindow: fillsWindow)
		return (peopleOnly, .row)
	}
}
