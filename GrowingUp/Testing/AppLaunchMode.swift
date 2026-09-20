import Foundation
import SwiftUI

enum AppLaunchMode {
	case live
	#if DEBUG
		case uiTest(UITestConfiguration)
	#endif

	static var current: Self {
		#if DEBUG
			guard let encodedConfiguration = ProcessInfo.processInfo.environment[UITestConfiguration.environmentKey] else {
				return .live
			}
			do {
				return .uiTest(try UITestConfiguration.decode(encodedConfiguration))
			} catch {
				fatalError("Invalid UI test configuration: \(error)")
			}
		#else
			return .live
		#endif
	}

	var preferredColorScheme: ColorScheme? {
		switch self {
		case .live:
			return nil
		#if DEBUG
			case let .uiTest(configuration):
				return configuration.appearance.colorScheme
		#endif
		}
	}
}
