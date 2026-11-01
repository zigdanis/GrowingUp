import SwiftUI

/// The milestone-first age over a person's photo: the name, the largest unit in huge type, the next unit and a live ticker.
///
/// Only the ticker changes every second; the lines above it keep their size so nothing jumps while it counts.
struct PersonAgeCard: View {
	let name: String
	let primaryValue: String
	let primaryUnit: String
	let secondaryText: String?
	let tickerText: String
	let accessibilityAge: String
	/// Whether the pager shows this page. The paging scroll view keeps neighbouring pages loaded, so only the shown
	/// page carries the identifiers UI tests look up.
	var isShown = true
	/// Larger type for a wide iPad window, read from further away; the name keeps its size.
	var isLarge = false
	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(name)
				.font(.largeTitle.bold())
				.lineLimit(2)
				.minimumScaleFactor(0.7)
			ViewThatFits(in: .horizontal) {
				HStack(alignment: .firstTextBaseline, spacing: 10) {
					value
					unit
				}
				VStack(alignment: .leading, spacing: 0) {
					value
					unit
				}
			}
			// A blank line keeps the ticker in place while there is no second unit to show.
			Text(secondaryText ?? " ")
				.font((isLarge ? Font.title2 : .title3).weight(.semibold))
				.monospacedDigit()
			Text(tickerText)
				.font((isLarge ? Font.body : .subheadline).weight(.medium).monospacedDigit())
				.foregroundStyle(.white.opacity(0.8))
				.padding(.top, 6)
		}
		.foregroundStyle(.white)
		.shadow(color: .black.opacity(0.35), radius: 8, y: 2)
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .ignore)
		.accessibilityAddTraits(.isStaticText)
		.accessibilityLabel(Text(name))
		.accessibilityValue(Text(accessibilityAge))
		.accessibilityIdentifier(isShown ? "person.name" : "")
	}

	private var value: some View {
		Text(primaryValue)
			.font(.system(size: isLarge ? 108 : 84, weight: .bold, design: .rounded))
			.monospacedDigit()
			.lineLimit(1)
			.minimumScaleFactor(0.5)
			.contentTransition(reduceMotion ? .identity : .numericText())
			.animation(reduceMotion ? nil : .snappy, value: primaryValue)
	}

	private var unit: some View {
		Text(primaryUnit)
			.font((isLarge ? Font.largeTitle : .title).weight(.semibold))
	}
}
