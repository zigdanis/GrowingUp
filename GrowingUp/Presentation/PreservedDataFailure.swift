/// A step on preserved data that failed and that the sheet's alert explains; the preserved data is untouched either way.
enum PreservedDataFailure: Identifiable {
	case export
	case delete

	var id: Self { self }

	var title: String {
		switch self {
		case .export: String(localized: "Couldn't export the copy")
		case .delete: String(localized: "Couldn't delete the copy")
		}
	}

	var message: String {
		switch self {
		case .export: String(localized: "Your earlier data is still kept on this device. Free up some space and try again.")
		case .delete: String(localized: "Try again in a moment.")
		}
	}
}
