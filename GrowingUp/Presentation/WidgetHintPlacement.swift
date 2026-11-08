/// Where the Home Screen widget hint sits in the mosaic.
enum WidgetHintPlacement: Equatable {
	/// A tile-sized card in the free slot at this index, in the last row.
	case slot(Int)
	/// A row as wide as the grid, after the last row of tiles.
	case row
}
