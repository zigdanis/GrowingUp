import Core
import SwiftUI

/// One person in the mosaic: their photo or monogram in the screen's portrait shape, with the name and the compact age in
/// the top-leading corner over a dark fade, as on the widget.
struct MosaicTile: View {
	static let cornerRadius: CGFloat = 22

	let person: Person
	/// The tile picture; nil while it loads.
	let picture: UIImage?
	let now: () -> Date
	@Environment(\.locale)
	private var locale
	@Environment(\.colorScheme)
	private var colorScheme

	var body: some View {
		Color.clear
			.overlay {
				if let picture {
					Image(uiImage: picture)
						.resizable()
						.scaledToFill()
						.accessibilityHidden(true)
				} else {
					Rectangle().fill(.quaternary)
				}
			}
			.overlay {
				LinearGradient(
					stops: [.init(color: .black.opacity(0.5), location: 0), .init(color: .clear, location: 0.42)], startPoint: .top,
					endPoint: .bottom)
			}
			.overlay(alignment: .topLeading) {
				// Ages count up only in their largest unit here, so the tile refreshes once a minute at most.
				TimelineView(.periodic(from: person.birthday, by: 60)) { _ in
					label(summary: AgeSummary(birthday: person.birthday, now: now(), finestUnit: .minutes))
				}
			}
			.clipShape(.rect(cornerRadius: Self.cornerRadius))
			.contentShape(.rect(cornerRadius: Self.cornerRadius))
			.compositingGroup()
			.shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.22), radius: 13, y: 10)
	}

	private func label(summary: AgeSummary) -> some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(person.name)
				.font(.subheadline.bold())
				.lineLimit(1)
			Text(summary.primary.localizedString(locale: locale))
				.font(.title2.bold())
				.lineLimit(1)
				.minimumScaleFactor(0.6)
		}
		.foregroundStyle(.white)
		.shadow(color: .black.opacity(0.5), radius: 2, y: 1)
		.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
		.padding(.horizontal, 14)
		.padding(.top, 14)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(Self.accessibilityLabel(name: person.name, summary: summary, locale: locale)))
	}

	/// The name and the compact age, such as "Alice, 5 years, 3 months".
	static func accessibilityLabel(name: String, summary: AgeSummary, locale: Locale) -> String {
		"\(name), \(summary.localizedCompact(locale: locale))"
	}
}
