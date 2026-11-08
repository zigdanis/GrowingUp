import SwiftUI
import WidgetKit

/// The pinned people as photo tiles that fill the widget edge to edge, split into rows by `WidgetTileLayout`.
struct AgeWidgetContentView: View {
	let entry: AgeEntry
	let family: WidgetFamily

	/// The gap between tiles, which shows the widget background as a thin seam.
	private static let seam: CGFloat = 2

	var body: some View {
		switch entry.content {
		case .nobodyPinned:
			EmptyWidgetView(isCompact: family == .systemSmall)
		case .unavailable:
			UnavailableWidgetView(isCompact: family == .systemSmall)
		case .loaded(let persons):
			if family == .systemSmall {
				smallView(persons[0])
			} else {
				tiles(persons)
			}
		}
	}

	// One person over their photo, which `AgeWidgetBackground` supplies; the whole widget deep-links to them.
	private func smallView(_ person: WidgetPerson) -> some View {
		PersonTile(person: person, date: entry.date, family: family)
			.widgetURL(person.deepLinkURL)
	}

	// Rows of independently tappable tiles in pinned order, so each keeps its deep link.
	private func tiles(_ persons: [WidgetPerson]) -> some View {
		VStack(spacing: Self.seam) {
			ForEach(WidgetTileLayout.rows(count: persons.count, family: family), id: \.lowerBound) { row in
				HStack(spacing: Self.seam) {
					ForEach(persons[row]) { person in
						link(to: person)
					}
				}
			}
		}
	}

	private func link(to person: WidgetPerson) -> some View {
		Link(destination: person.deepLinkURL) {
			PersonTile(person: person, date: entry.date, family: family)
		}
		.buttonStyle(.plain)
	}
}
