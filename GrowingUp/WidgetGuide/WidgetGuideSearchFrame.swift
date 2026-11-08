import SwiftUI

/// Step 3: the widget gallery slides up, "GrowingUp" is typed into its search field, and the app comes up.
struct WidgetGuideSearchFrame: View {
	let isAnimated: Bool
	/// The name the user types, the same in every language.
	private static let query = "GrowingUp"

	var body: some View {
		WidgetGuideCanvas {
			PlaceholderIconGrid(count: 4, isEditing: true)
				.frame(width: 297)
				.offset(x: 28, y: 20)
				.opacity(0.5)
			if isAnimated {
				// One letter at a time, then the result, held for a moment before it plays again.
				PhaseAnimator(Array(0...Self.query.count)) { typed in
					gallery(typed: typed)
				} animation: { typed in
					typed == 0 ? .linear(duration: 0.01).delay(1.2) : .linear(duration: 0.12)
				}
			} else {
				gallery(typed: Self.query.count)
			}
		}
	}

	private func gallery(typed: Int) -> some View {
		VStack(spacing: 0) {
			Capsule().fill(.white.opacity(0.3)).frame(width: 36, height: 5).padding(.bottom, 12)
			HStack(spacing: 8) {
				Image(systemName: "magnifyingglass").opacity(0.6)
				Text(Self.query.prefix(typed))
				Rectangle().fill(Color.blue).frame(width: 2, height: 20)
				Spacer()
			}
			.font(.system(size: 16))
			.padding(.horizontal, 12)
			.frame(height: 38)
			.background(.white.opacity(0.1), in: .rect(cornerRadius: 12))
			HStack(spacing: 12) {
				AppIconImage(size: 40)
				Text(Self.query).font(.system(size: 16, weight: .semibold))
				Spacer()
				Image(systemName: "chevron.right").opacity(0.5)
			}
			.padding(8)
			.background(Color(uiColor: .appColor).opacity(0.16), in: .rect(cornerRadius: 12))
			.padding(.top, 14)
			.opacity(typed == Self.query.count ? 1 : 0)
			RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.06)).frame(height: 90).padding(.top, 14)
			Spacer(minLength: 0)
		}
		.foregroundStyle(.white)
		.padding(.horizontal, 16)
		.padding(.top, 10)
		.frame(width: 353, height: 300 - 34)
		.background(Color(red: 0.14, green: 0.14, blue: 0.15), in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
		.offset(y: 34)
	}
}
