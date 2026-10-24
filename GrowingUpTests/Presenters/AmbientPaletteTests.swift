import SwiftUI
import XCTest

@testable import GrowingUp

final class AmbientPaletteTests: XCTestCase {
	func testTheMeshHasAColourForEveryPoint() {
		XCTAssertEqual(AmbientPalette.points.count, 16)
		XCTAssertEqual(AmbientPalette(seeds: [.red], colorScheme: .dark).colors.count, 16)
		XCTAssertEqual(AmbientPalette(seeds: [], colorScheme: .light).colors.count, 16)
	}

	func testTheDarkVariantIsDarkAndTheLightVariantLight() {
		let seeds: [UIColor] = [.systemOrange, .systemGreen, .systemTeal, .systemYellow]
		let dark = AmbientPalette(seeds: seeds, colorScheme: .dark).colors.map(Self.luminance)
		let light = AmbientPalette(seeds: seeds, colorScheme: .light).colors.map(Self.luminance)
		XCTAssertLessThan(dark.max() ?? 1, 0.5)
		XCTAssertGreaterThan(light.min() ?? 0, 0.6)
	}

	func testSpotsTakeTheirPeoplesColoursAndRepeatThemForFewerPeople() {
		let palette = AmbientPalette(seeds: [.red, .blue], colorScheme: .dark)
		// The inner points 5, 6, 9 and 10 are the four spots, in mosaic order.
		let spots = [5, 6, 9, 10].map { Self.rgb(of: palette.colors[$0]) }
		XCTAssertGreaterThan(spots[0][0], spots[0][2], "The first spot leans red")
		XCTAssertGreaterThan(spots[1][2], spots[1][0], "The second spot leans blue")
		for (repeated, original) in [(spots[2], spots[0]), (spots[3], spots[1])] {
			for (channel, expected) in zip(repeated, original) {
				XCTAssertEqual(channel, expected, accuracy: 0.001)
			}
		}
	}

	func testTheEmptyMosaicGlowsInTheAppColour() {
		let palette = AmbientPalette(seeds: [], colorScheme: .dark)
		XCTAssertEqual(Self.hue(of: palette.colors[5]), Self.hue(of: .appColor), accuracy: 0.03)
	}

	func testTintsAreLivelierButNeverGlaring() {
		let grey = UIColor(white: 0.97, alpha: 1)
		let tint = AmbientPalette.tint(UIColor(red: 0.9, green: 0.8, blue: 0.7, alpha: 1), isDark: true)
		var saturation: CGFloat = 0
		var brightness: CGFloat = 0
		tint.getHue(nil, saturation: &saturation, brightness: &brightness, alpha: nil)
		XCTAssertGreaterThan(saturation, 0.3)
		XCTAssertLessThanOrEqual(brightness, 0.8 + 0.001)
		AmbientPalette.tint(grey, isDark: false).getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
		XCTAssertLessThanOrEqual(brightness, 0.9 + 0.001)
	}

	private static func luminance(_ colour: UIColor) -> CGFloat {
		let channels = rgb(of: colour)
		return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
	}

	private static func rgb(of colour: UIColor) -> [CGFloat] {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		colour.getRed(&red, green: &green, blue: &blue, alpha: nil)
		return [red, green, blue]
	}

	private static func hue(of colour: UIColor) -> CGFloat {
		var hue: CGFloat = 0
		colour.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
		return hue
	}
}
