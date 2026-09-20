//
//  AgeWidgetEntryView.swift
//  Widget
//
//  SwiftUI views for the GrowingUp WidgetKit widget. Renders the pinned people
//  with their age at the entry's date, reusing `AgeCalculator` from Core.
//

import Core
import SwiftUI
import WidgetKit

struct AgeWidgetEntryView: View {
	@Environment(\.widgetFamily)
	private var family
	let entry: AgeEntry

	var body: some View {
		if entry.persons.isEmpty {
			EmptyWidgetView()
		} else {
			switch family {
			case .systemSmall:
				smallView
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
			ForEach(entry.persons) { person in
				Link(destination: person.deepLinkURL) {
					PersonCell(person: person, date: entry.date, compact: false)
						.frame(maxWidth: .infinity)
				}
			}
		}
	}
}
