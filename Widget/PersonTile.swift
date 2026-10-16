import SwiftUI
import WidgetKit

/// One person in a widget: name, a huge primary age number with its unit, and a secondary or birthday caption.
///
/// Medium and large tiles carry their own photo; the small widget's photo is the widget background instead, so the
/// system can round it with the widget.
struct PersonTile: View {
	let person: WidgetPerson
	let date: Date
	let family: WidgetFamily
	@Environment(\.locale)
	private var locale

	var body: some View {
		let content = PersonTileContent(person: person, date: date, locale: locale)
		Group {
			if family == .systemSmall {
				label(content)
			} else {
				label(content)
					.padding(8)
					.background { PersonPhotoBackground(photo: person.photo) }
					.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(content.accessibilityLabel)
	}

	private var valueSize: CGFloat {
		switch family {
		case .systemSmall: 52
		case .systemMedium: 36
		default: 34
		}
	}

	private func label(_ content: PersonTileContent) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack(alignment: .top, spacing: 4) {
				Text(content.name).font(.caption.weight(.semibold)).lineLimit(1)
				Spacer(minLength: 0)
				if content.isBirthday { cakeBadge }
			}
			Spacer(minLength: 0)
			Text(content.value)
				.font(.system(size: valueSize, weight: .bold, design: .rounded))
				.monospacedDigit()
				.lineLimit(1)
				.minimumScaleFactor(0.5)
			Text(content.unit)
				.font((family == .systemSmall ? Font.footnote : Font.caption).weight(.semibold))
				.foregroundStyle(.white.opacity(0.9))
				.lineLimit(1)
				.minimumScaleFactor(0.6)
			if let caption = content.caption {
				Text(caption)
					.font(.caption2)
					.foregroundStyle(.white.opacity(0.8))
					.lineLimit(2)
					.minimumScaleFactor(0.6)
					.padding(.top, 2)
			}
		}
		.foregroundStyle(.white)
		.shadow(color: .black.opacity(0.4), radius: 2, y: 1)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
	}

	private var cakeBadge: some View {
		Image(systemName: "birthday.cake.fill")
			.font(.system(size: 10, weight: .bold))
			.foregroundStyle(.white)
			.frame(width: 20, height: 20)
			.background(Circle().fill(.pink))
	}
}
