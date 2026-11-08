import SwiftUI
import UIKit

/// GrowingUp's own app icon, as the widget gallery shows it, read from the bundle's primary icon; a plain rounded square
/// in the app colour stands in when the bundle has none to offer.
struct AppIconImage: View {
	var size: CGFloat = 40

	private static let icon: UIImage? = {
		let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
		let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
		let name = (primary?["CFBundleIconFiles"] as? [String])?.last ?? primary?["CFBundleIconName"] as? String
		return name.flatMap { UIImage(named: $0) }
	}()

	var body: some View {
		Group {
			if let icon = Self.icon {
				Image(uiImage: icon).resizable()
			} else {
				Color(uiColor: .appColor)
			}
		}
		.frame(width: size, height: size)
		.clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
	}
}
