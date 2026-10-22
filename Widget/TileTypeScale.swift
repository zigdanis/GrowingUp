import CoreGraphics

/// Text sizes and insets of a widget tile, chosen from the tile's size: one person on a large widget reads at a glance,
/// six still fit their numbers.
struct TileTypeScale: Equatable {
	let name: CGFloat
	let value: CGFloat
	let unit: CGFloat
	let caption: CGFloat
	/// The distance of the text from the tile's edges, enough to clear the widget's rounded corners on edge tiles.
	let inset: CGFloat

	init(tileSize size: CGSize) {
		switch (size.width, size.height) {
		case (_, 300...): self.init(name: 22, value: 80, unit: 24, caption: 17, inset: 22)
		case (300..., 160...): self.init(name: 17, value: 56, unit: 20, caption: 15, inset: 18)
		case (160..., 140...): self.init(name: 17, value: 48, unit: 18, caption: 15, inset: 16)
		case (..<115, _): self.init(name: 16, value: 44, unit: 16, caption: 13, inset: 12)
		default: self.init(name: 17, value: 44, unit: 17, caption: 15, inset: 14)
		}
	}

	init(name: CGFloat, value: CGFloat, unit: CGFloat, caption: CGFloat, inset: CGFloat) {
		self.name = name
		self.value = value
		self.unit = unit
		self.caption = caption
		self.inset = inset
	}
}
