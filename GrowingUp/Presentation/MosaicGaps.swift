import SwiftUI

/// The mosaic's scroll content with holes where its tiles sit: the margins, the gaps and the space below the last row.
///
/// Laid over the tiles with an even-odd content shape, it takes the taps beside the tiles, which the tiles would otherwise
/// claim: a tile's touch area reaches into the gaps around it.
struct MosaicGaps: Shape {
	let grid: MosaicGridLayout
	/// How many tiles the mosaic shows.
	let count: Int

	func path(in rect: CGRect) -> Path {
		var path = Path(rect)
		for slot in 0..<count {
			let origin = grid.origin(ofSlot: slot, width: rect.width)
			path.addRoundedRect(
				in: CGRect(origin: origin, size: CGSize(width: grid.tileWidth, height: grid.tileHeight)),
				cornerSize: CGSize(width: MosaicTile.cornerRadius, height: MosaicTile.cornerRadius))
		}
		return path
	}
}
