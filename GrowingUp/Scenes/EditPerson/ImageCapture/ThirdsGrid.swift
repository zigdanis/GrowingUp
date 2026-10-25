import SwiftUI

/// The rule-of-thirds guide over a crop frame: two vertical and two horizontal lines.
struct ThirdsGrid: Shape {
	func path(in rect: CGRect) -> Path {
		Path { path in
			for line in 1...2 {
				let lineX = rect.minX + rect.width * CGFloat(line) / 3
				path.move(to: CGPoint(x: lineX, y: rect.minY))
				path.addLine(to: CGPoint(x: lineX, y: rect.maxY))
				let lineY = rect.minY + rect.height * CGFloat(line) / 3
				path.move(to: CGPoint(x: rect.minX, y: lineY))
				path.addLine(to: CGPoint(x: rect.maxX, y: lineY))
			}
		}
	}
}
