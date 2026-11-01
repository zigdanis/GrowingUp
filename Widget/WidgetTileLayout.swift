import Core
import WidgetKit

/// How a Home Screen widget splits its people into rows, so the tiles always fill the widget and no slot is left empty.
///
/// People keep their pinned order. When the rows differ in length the first row is the shorter one, so the first person
/// gets the wider tile: three people on a large widget are one wide tile over two halves, five are two over three. An
/// extra large widget, iPad's, splits its people the same way.
enum WidgetTileLayout {
	/// The index ranges of the people shown in each row of a `family` widget, from top to bottom.
	static func rows(count: Int, family: WidgetFamily) -> [Range<Int>] {
		let shown = min(max(count, 0), capacity(of: family))
		guard shown > 1, family == .systemLarge || family == .systemExtraLarge else {
			return shown > 0 ? [0..<shown] : []
		}
		let firstRow = shown <= 3 ? 1 : shown / 2
		return [0..<firstRow, firstRow..<shown]
	}

	/// The most people a `family` widget shows.
	static func capacity(of family: WidgetFamily) -> Int {
		switch family {
		case .systemSmall: 1
		case .systemMedium: 3
		default: Constants.widgetPeopleLimit
		}
	}
}
