import Core
import WidgetKit

/// Asks WidgetKit whether a GrowingUp Home Screen widget is installed. Widgets in the Today View report the same kind
/// and families, so they count too; the Lock Screen widget is another kind.
enum InstalledWidgetLookup {
	/// Whether a GrowingUp Home Screen widget of any size is installed; nil when WidgetKit can't say.
	static func isHomeScreenWidgetInstalled() async -> Bool? {
		await withCheckedContinuation { continuation in
			WidgetCenter.shared.getCurrentConfigurations { result in
				switch result {
				case .success(let widgets):
					continuation.resume(returning: widgets.contains { isHomeScreenWidget(kind: $0.kind, family: $0.family) })
				case .failure:
					continuation.resume(returning: nil)
				}
			}
		}
	}

	static func isHomeScreenWidget(kind: String, family: WidgetFamily) -> Bool {
		guard kind == Constants.homeScreenWidgetKind else { return false }
		switch family {
		case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge: return true
		default: return false
		}
	}
}
