import SwiftUI

extension EnvironmentValues {
	/// The app's touch feedback; silent unless the app's root installs `SystemHaptics`.
	@Entry var haptics: any Haptics = NoHaptics()
}
