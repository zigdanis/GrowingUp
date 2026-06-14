//
//  AgeWidgetView.swift
//  Widget
//
//  SwiftUI views for the GrowingUp WidgetKit widget. Renders the pinned people
//  with their age at the entry's date, reusing `AgeCalculator` from Core.
//

import WidgetKit
import SwiftUI
import Core

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

private struct PersonCell: View {
	let person: WidgetPerson
	let date: Date
	let compact: Bool

	private var ageText: String {
		let components = AgeCalculator.ageComponents(from: person.birthday, to: date)
		return AgeCalculator.ageString(for: components)
	}

	var body: some View {
		VStack(spacing: 6) {
			face
				.frame(width: compact ? 56 : 48, height: compact ? 56 : 48)
				.clipShape(Circle())
			Text(person.name)
				.font(.caption)
				.fontWeight(.semibold)
				.lineLimit(1)
			Text(ageText)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.lineLimit(compact ? 4 : 3)
				.minimumScaleFactor(0.7)
		}
		.padding(.horizontal, 4)
	}

	@ViewBuilder private var face: some View {
		if let image = person.image {
			Image(uiImage: image)
				.resizable()
				.scaledToFill()
		} else {
			Image("face")
				.resizable()
				.scaledToFit()
				.foregroundStyle(.secondary)
		}
	}
}

private struct EmptyWidgetView: View {
	var body: some View {
		VStack(spacing: 8) {
			Image(systemName: "person.crop.circle.badge.plus")
				.font(.title)
				.foregroundStyle(.secondary)
			Text("Add a person")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.widgetURL(URL(string: "growingup-app://add-person"))
	}
}
