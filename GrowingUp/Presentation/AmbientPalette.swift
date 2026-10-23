import SwiftUI
import UIKit

/// The colours of the mosaic's ambient background: four soft spots tinted by the first people's photos over a calm base,
/// as a 4×4 mesh.
///
/// The spots sit roughly where the first four tiles stand. Each tint is a photo's average colour with its saturation
/// lifted and its brightness held in a band, so the background stays warm while the tiles remain the brightest thing on
/// screen. The dark variant lays strong tints on a deep blue-grey; the light variant lays pale ones on warm paper.
struct AmbientPalette: Equatable {
	/// The mesh's points, row by row; the inner four are the spots.
	static let points: [SIMD2<Float>] = [
		[0, 0], [0.22, 0], [0.8, 0], [1, 0],
		[0, 0.24], [0.22, 0.24], [0.8, 0.3], [1, 0.3],
		[0, 0.72], [0.2, 0.72], [0.8, 0.76], [1, 0.76],
		[0, 1], [0.2, 1], [0.8, 1], [1, 1]
	]
	/// For each mesh point, the spot it takes its tint from and how much of the spot's strength it keeps; the inner
	/// points are the spots themselves, the edges fade towards the base.
	private static let influence: [(spot: Int, share: CGFloat)] = [
		(0, 0.35), (0, 0.55), (1, 0.55), (1, 0.35),
		(0, 0.55), (0, 1), (1, 1), (1, 0.55),
		(2, 0.55), (2, 1), (3, 1), (3, 0.55),
		(2, 0.35), (2, 0.55), (3, 0.55), (3, 0.35)
	]
	/// The warm second spot of the empty mosaic, beside the app colour.
	private static let emptyWarmth = UIColor(red: 0.66, green: 0.53, blue: 0.37, alpha: 1)

	/// One colour per mesh point, in the order of `points`.
	let colors: [UIColor]

	/// - Parameters:
	///   - seeds: the average photo colours of the first people in mosaic order; the spots repeat them when there are
	///     fewer than four. With none, the app colour and a warm tone tint the background instead.
	///   - colorScheme: picks the dark or light variant.
	init(seeds: [UIColor], colorScheme: ColorScheme) {
		let isDark = colorScheme == .dark
		let base = isDark ? UIColor(red: 0.114, green: 0.133, blue: 0.188, alpha: 1) : UIColor(red: 0.957, green: 0.949, blue: 0.933, alpha: 1)
		let spots: [(color: UIColor, strength: CGFloat)?]
		if seeds.isEmpty {
			spots = [(.appColor, isDark ? 0.55 : 0.4), nil, nil, (Self.emptyWarmth, isDark ? 0.5 : 0.3)]
		} else {
			spots = (0..<4).map { index in
				(Self.tint(seeds[index % seeds.count], isDark: isDark), isDark ? 0.72 : 0.34)
			}
		}
		colors = Self.influence.map { point in
			guard let spot = spots[point.spot] else { return base }
			return Self.mix(base, spot.color, amount: spot.strength * point.share)
		}
	}

	var meshColors: [Color] { colors.map(Color.init(uiColor:)) }

	/// A photo's average colour made to glow: more saturated, and neither muddy nor glaring in the variant's band.
	static func tint(_ color: UIColor, isDark: Bool) -> UIColor {
		var hue: CGFloat = 0
		var saturation: CGFloat = 0
		var brightness: CGFloat = 0
		var alpha: CGFloat = 0
		guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return color }
		let lifted = min(1, saturation * 1.35 + 0.05)
		let band: ClosedRange<CGFloat> = isDark ? 0.45...0.8 : 0.6...0.9
		return UIColor(hue: hue, saturation: lifted, brightness: min(max(brightness, band.lowerBound), band.upperBound), alpha: 1)
	}

	/// `amount` of `top` laid over `bottom` in sRGB, like CSS `color-mix`.
	static func mix(_ bottom: UIColor, _ top: UIColor, amount: CGFloat) -> UIColor {
		let share = min(max(amount, 0), 1)
		let mixed = zip(rgb(of: bottom), rgb(of: top)).map { lower, upper in lower + (upper - lower) * share }
		return UIColor(red: mixed[0], green: mixed[1], blue: mixed[2], alpha: 1)
	}

	private static func rgb(of color: UIColor) -> [CGFloat] {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
		return [red, green, blue]
	}
}
