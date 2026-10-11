import Core
import SwiftUI
import WidgetKit

struct AgeWidgetContentView: View {
	let entry: AgeEntry
	let family: WidgetFamily

	var body: some View {
		if entry.persons.isEmpty {
			EmptyWidgetView()
		} else {
			switch family {
			case .systemSmall:
				smallView
			case .systemLarge:
				largeView
			default:
				mediumView
			}
		}
	}

	// One person, whole widget deep-links to that person.
	private var smallView: some View {
		let person = entry.persons[0]
		return PersonCell(person: person, date: entry.date, compact: true)
			.widgetURL(person.deepLinkURL)
	}

	// Up to three people side by side, each independently tappable.
	private var mediumView: some View {
		HStack(spacing: 0) {
			ForEach(entry.persons.prefix(3)) { person in
				Link(destination: person.deepLinkURL) {
					PersonCell(person: person, date: entry.date, compact: false)
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.plain)
			}
		}
	}

	// Up to six people in two rows, preserving the provider's deep-link indices.
	private var largeView: some View {
		GeometryReader { geometry in
			LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 16) {
				ForEach(entry.persons.prefix(Constants.widgetPeopleLimit)) { person in
					Link(destination: person.deepLinkURL) {
						PersonCell(person: person, date: entry.date, compact: false)
							.frame(maxWidth: .infinity)
							.frame(height: max(0, (geometry.size.height - 16) / 2))
					}
					.buttonStyle(.plain)
				}
			}
		}
	}
}
