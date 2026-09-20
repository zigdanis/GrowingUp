import UIKit

enum PreviewPhotos {
	static let images = [
		image(symbol: "figure.2.and.child.holdinghands", colors: [.systemOrange, .systemPink]),
		image(symbol: "mountain.2.fill", colors: [.systemTeal, .systemBlue]), image(symbol: "sun.max.fill", colors: [.systemYellow, .systemOrange]),
		image(symbol: "pawprint.fill", colors: [.systemIndigo, .systemPurple]), image(symbol: "balloon.2.fill", colors: [.systemPink, .systemRed]),
		image(symbol: "tree.fill", colors: [.systemGreen, .systemTeal]), image(symbol: "beach.umbrella.fill", colors: [.systemCyan, .systemBlue]),
		image(symbol: "birthday.cake.fill", colors: [.systemPink, .systemOrange]), image(symbol: "bicycle", colors: [.systemGreen, .systemBlue]),
		image(symbol: "camera.fill", colors: [.systemPurple, .systemPink]), image(symbol: "car.fill", colors: [.systemRed, .systemOrange]),
		image(symbol: "cloud.sun.fill", colors: [.systemBlue, .systemYellow]), image(symbol: "figure.hiking", colors: [.systemBrown, .systemGreen]),
		image(symbol: "fish.fill", colors: [.systemTeal, .systemIndigo]), image(symbol: "gift.fill", colors: [.systemRed, .systemPurple]),
		image(symbol: "house.fill", colors: [.systemOrange, .systemBrown]), image(symbol: "moon.stars.fill", colors: [.systemIndigo, .black]),
		image(symbol: "sailboat.fill", colors: [.systemCyan, .systemTeal])
	]

	private static func image(symbol: String, colors: [UIColor]) -> UIImage {
		let size = CGSize(width: 360, height: 360)
		return UIGraphicsImageRenderer(size: size).image { context in
			let gradient = CGGradient(
				colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: [0, 1])!
			context.cgContext.drawLinearGradient(
				gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
			let configuration = UIImage.SymbolConfiguration(pointSize: 110, weight: .medium)
			let icon = UIImage(systemName: symbol, withConfiguration: configuration)!
			icon.withTintColor(.white, renderingMode: .alwaysOriginal).draw(
				at: CGPoint(x: (size.width - icon.size.width) / 2, y: (size.height - icon.size.height) / 2))
		}
	}
}
