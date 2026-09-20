import SwiftUI

enum UITestAppearance: String, Codable, CaseIterable {
	case light
	case dark

	var colorScheme: ColorScheme {
		switch self {
		case .light: .light
		case .dark: .dark
		}
	}

	var launchArgumentValue: String { rawValue.capitalized }
}
