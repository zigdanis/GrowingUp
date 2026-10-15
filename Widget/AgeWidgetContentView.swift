import Core
import SwiftUI
import WidgetKit

struct AgeWidgetContentView: View {
	let entry: AgeEntry
	let family: WidgetFamily

	private static let columns = 3

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

	// One person over their photo, which `AgeWidgetBackground` supplies; the whole widget deep-links to them.
	private var smallView: some View {
		let person = entry.persons[0]
		return PersonTile(person: person, date: entry.date, family: family)
			.widgetURL(person.deepLinkURL)
	}

	// Up to three photo tiles side by side, each independently tappable.
	private var mediumView: some View {
		HStack(spacing: 8) {
			ForEach(entry.persons.prefix(Self.columns)) { person in
				link(to: person)
			}
		}
	}

	// Up to six equally sized tiles in rows of three, preserving the provider's deep-link indices.
	private var largeView: some View {
		let persons = Array(entry.persons.prefix(Constants.widgetPeopleLimit))
		let rows = Constants.widgetPeopleLimit / Self.columns
		return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
			ForEach(0..<rows, id: \.self) { row in
				GridRow {
					ForEach(0..<Self.columns, id: \.self) { column in
						let index = row * Self.columns + column
						if index < persons.count {
							link(to: persons[index])
						} else {
							Color.clear
						}
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
