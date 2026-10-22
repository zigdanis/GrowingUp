import SwiftUI
import WidgetKit

/// The pinned people as photo tiles that fill the widget edge to edge, split into rows by `WidgetTileLayout`.
struct AgeWidgetContentView: View {
	let entry: AgeEntry
	let family: WidgetFamily

	/// The gap between tiles, which shows the widget background as a thin seam.
	private static let seam: CGFloat = 2

	var body: some View {
		if entry.persons.isEmpty {
			EmptyWidgetView(isCompact: family == .systemSmall)
		} else if family == .systemSmall {
			smallView
		} else {
			tiles
		}
	}

	// One person over their photo, which `AgeWidgetBackground` supplies; the whole widget deep-links to them.
	private var smallView: some View {
		let person = entry.persons[0]
		return PersonTile(person: person, date: entry.date, family: family)
			.widgetURL(person.deepLinkURL)
	}

	// Rows of independently tappable tiles in pinned order, so each keeps its deep link.
	private var tiles: some View {
		VStack(spacing: Self.seam) {
			ForEach(WidgetTileLayout.rows(count: entry.persons.count, family: family), id: \.lowerBound) { row in
				HStack(spacing: Self.seam) {
					ForEach(entry.persons[row]) { person in
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
