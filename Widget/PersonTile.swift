import SwiftUI
import WidgetKit

/// One person in a widget: name, a huge primary age number with its unit, and a secondary or birthday caption.
///
/// Medium and large tiles carry their own picture and meet at thin seams, edge to edge; the small widget's picture is the
/// widget background instead, so the system can round it with the widget and remove it in StandBy.
struct PersonTile: View {
	let person: WidgetPerson
	let date: Date
	let family: WidgetFamily
	@Environment(\.locale)
	private var locale

	var body: some View {
		let content = PersonTileContent(person: person, date: date, locale: locale)
		GeometryReader { proxy in
			let scale = TileTypeScale(tileSize: proxy.size)
			label(content, scale: scale)
				.padding(scale.inset)
		}
		.background {
			if family != .systemSmall { PersonPhotoBackground(person: person) }
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(content.accessibilityLabel)
	}

	private func label(_ content: PersonTileContent, scale: TileTypeScale) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack(alignment: .top, spacing: 4) {
				Text(content.name).font(.system(size: scale.name, weight: .semibold)).lineLimit(1)
				Spacer(minLength: 0)
				if content.isBirthday { cakeBadge }
			}
			Spacer(minLength: 0)
			Text(content.value)
				.font(.system(size: scale.value, weight: .bold, design: .rounded))
				.monospacedDigit()
				.lineLimit(1)
				.minimumScaleFactor(0.7)
			Text(content.unit)
				.font(.system(size: scale.unit, weight: .semibold))
				.foregroundStyle(.white.opacity(0.9))
				.lineLimit(1)
				.minimumScaleFactor(0.6)
			if let caption = content.caption {
				Text(caption)
					.font(.system(size: scale.caption))
					.foregroundStyle(.white.opacity(0.85))
					.lineLimit(2)
					.minimumScaleFactor(0.75)
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
			.background { Circle().fill(.pink) }
	}
}
