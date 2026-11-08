import SwiftUI

/// The quiet hint at the end of the mosaic that the app has a Home Screen widget: a tiny Home Screen with the real widget
/// and the user's own people, "On your Home Screen too", a line on what the widget shows and "See how".
///
/// A tap anywhere but × opens the widget guide; × closes it. Either way it is gone for good. In a free slot of the last
/// row it is a tile-sized card; after a full row it is a row as wide as the grid. VoiceOver reads it as one button with
/// a separate "Close" action.
struct WidgetHintStrip: View {
	let placement: WidgetHintPlacement
	/// The pinned people, as the widget shows them; nil while they load.
	let entry: AgeEntry?
	let onOpen: () -> Void
	let onDismiss: () -> Void
	@Environment(\.dynamicTypeSize)
	private var dynamicTypeSize

	private var isCard: Bool { placement != .row }

	var body: some View {
		Button(action: onOpen) {
			content
				.frame(maxWidth: .infinity, maxHeight: isCard ? .infinity : nil, alignment: .topLeading)
				.background { MosaicGlass(shape: .rect(cornerRadius: MosaicTile.cornerRadius, style: .continuous)) }
				.contentShape(.rect(cornerRadius: MosaicTile.cornerRadius, style: .continuous))
		}
		.buttonStyle(.plain)
		.contentShape(.hoverEffect, .rect(cornerRadius: MosaicTile.cornerRadius, style: .continuous))
		.hoverEffect(.lift)
		.overlay(alignment: .topTrailing) { closeButton }
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(accessibilityLabel))
		.accessibilityAddTraits(.isButton)
		.accessibilityAction(.default, onOpen)
		.accessibilityAction(named: Text("Close"), onDismiss)
		.accessibilityIdentifier("people.widgetHint")
	}

	@ViewBuilder
	private var content: some View {
		if isCard {
			card
		} else {
			row
		}
	}

	/// The tile-sized card: the Home Screen on top, the words below. When the words need all the room, as at the largest
	/// text sizes, the picture gives way, and words still taller than the tile scroll within it.
	private var card: some View {
		ViewThatFits(in: .vertical) {
			VStack(alignment: .leading, spacing: 14) {
				WidgetHintHomeScreen(entry: entry)
					.aspectRatio(154 / 150, contentMode: .fit)
				words(subtitle: "Widget with photos and ages of your people")
			}
			words(subtitle: "Widget with photos and ages of your people")
			ScrollView(.vertical) {
				words(subtitle: "Widget with photos and ages of your people")
			}
			.scrollBounceBehavior(.basedOnSize)
		}
		.padding(12)
	}

	/// The full-width row: the Home Screen beside the words, or above them at accessibility text sizes.
	private var row: some View {
		let layout =
			dynamicTypeSize.isAccessibilitySize
			? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
		return layout {
			WidgetHintHomeScreen(entry: entry)
				.frame(width: 128, height: 134)
			words(subtitle: "A widget with your people's photos and ages")
				.padding(.top, dynamicTypeSize.isAccessibilitySize ? 0 : 10)
				// Clear of ×.
				.padding(.trailing, 30)
		}
		.padding(10)
		.frame(minHeight: 156, alignment: .topLeading)
	}

	private func words(subtitle: LocalizedStringKey) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("On your Home Screen too")
				.font(.headline)
				.foregroundStyle(.primary)
				.lineLimit(3)
			Text(subtitle)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.lineLimit(4)
			Text("See how ›")
				.font(.subheadline.weight(.semibold))
				.foregroundStyle(Color(uiColor: .appColor))
				.padding(.top, 8)
		}
		.minimumScaleFactor(0.8)
		.fixedSize(horizontal: false, vertical: true)
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private var closeButton: some View {
		Button(action: onDismiss) {
			Image(systemName: "xmark")
				.font(.system(size: 11, weight: .bold))
				.foregroundStyle(isCard ? AnyShapeStyle(Color.white) : AnyShapeStyle(.secondary))
				.frame(width: 28, height: 28)
				.background(isCard ? AnyShapeStyle(Color.black.opacity(0.35)) : AnyShapeStyle(.fill.tertiary), in: .circle)
				// A finger-sized target around the small circle.
				.frame(width: 44, height: 44)
				.contentShape(.rect)
		}
		.buttonStyle(.plain)
		.accessibilityIdentifier("people.widgetHint.close")
	}

	private var accessibilityLabel: String {
		[
			String(localized: "On your Home Screen too"), String(localized: "A widget with your people's photos and ages"),
			String(localized: "See how")
		].joined(separator: ", ")
	}
}
