import SwiftUI

/// Rows of plain coloured squares that stand in for app icons on an illustrated Home Screen; no real app is shown.
///
/// In edit mode the icons tilt and show their remove badges, rocking back and forth while `isAnimated`.
struct PlaceholderIconGrid: View {
	static let colors: [Color] = [
		Color(red: 0.91, green: 0.63, blue: 0.36), Color(red: 0.42, green: 0.77, blue: 0.63), Color(red: 0.48, green: 0.61, blue: 0.94),
		Color(red: 0.89, green: 0.44, blue: 0.53), Color(red: 0.73, green: 0.55, blue: 0.90), Color(red: 0.36, green: 0.72, blue: 0.90),
		Color(red: 0.84, green: 0.76, blue: 0.35), Color(red: 0.54, green: 0.64, blue: 0.42), Color(red: 0.79, green: 0.48, blue: 0.35),
		Color(red: 0.35, green: 0.56, blue: 0.82), Color(red: 0.66, green: 0.66, blue: 0.72), Color(red: 0.88, green: 0.55, blue: 0.72)
	]

	let count: Int
	var horizontalSpacing: CGFloat = 24
	var verticalSpacing: CGFloat = 26
	var cornerRadius: CGFloat = 14
	/// Draws a short bar under each icon where its name would be.
	var showsLabels = true
	var isEditing = false
	var isAnimated = false

	var body: some View {
		LazyVGrid(
			columns: Array(repeating: GridItem(.flexible(), spacing: horizontalSpacing), count: 4), spacing: verticalSpacing
		) {
			ForEach(0..<count, id: \.self) { index in
				icon(index)
			}
		}
	}

	private func icon(_ index: Int) -> some View {
		let tilt: Double = index.isMultiple(of: 2) ? -3 : 3
		return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
			.fill(Self.colors[index % Self.colors.count])
			.aspectRatio(1, contentMode: .fit)
			.overlay(alignment: .topLeading) {
				if isEditing {
					Image(systemName: "minus")
						.font(.system(size: 10, weight: .heavy))
						.foregroundStyle(.black.opacity(0.75))
						.frame(width: 20, height: 20)
						.background(Color(white: 0.82, opacity: 0.9), in: .circle)
						.offset(x: -6, y: -6)
				}
			}
			.overlay(alignment: .bottom) {
				if showsLabels {
					Capsule().fill(.white.opacity(0.35)).frame(height: 5).padding(.horizontal, 10).offset(y: 14)
				}
			}
			.modifier(IconRocking(tilt: isEditing ? tilt : 0, isAnimated: isEditing && isAnimated))
	}
}
