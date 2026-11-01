import SwiftUI
import XCTest

@testable import GrowingUp

final class EditModeColumnWidthTests: XCTestCase {
	func testPhonesAndIPhoneDuoKeepTheirColumns() {
		XCTAssertNil(width(CGSize(width: 440, height: 956), .phone), "iPhone 17 Pro Max")
		XCTAssertEqual(width(CGSize(width: 466, height: 678), .phone), 466, "iPhone Duo's outer display: the whole window")
		XCTAssertEqual(width(CGSize(width: 669, height: 951), .phone), 600, "iPhone Duo upright: the 600 pt column")
		XCTAssertEqual(width(CGSize(width: 951, height: 669), .phone)!, 669 * CropGeometry.maxMainAspect, accuracy: 0.001)
	}

	func testFullScreenIPadsKeepTheirColumns() {
		XCTAssertEqual(width(CGSize(width: 1032, height: 1376), .pad), 600)
		XCTAssertEqual(width(CGSize(width: 1376, height: 1032), .pad), 480)
		XCTAssertEqual(width(CGSize(width: 744, height: 1133), .pad), 600)
		XCTAssertEqual(width(CGSize(width: 1133, height: 744), .pad), 480)
	}

	func testSmallIPadWindowsKeepRoomForTheControls() {
		let room = PersonEditModeScene.padMinimumChromeWidth + 2 * PersonEditModeScene.chromeMargin
		XCTAssertEqual(width(CGSize(width: 574, height: 486), .pad), room, "A crop column of 340 pt")
		XCTAssertEqual(width(CGSize(width: 788, height: 594), .pad), room, "A crop column of 416 pt")
		XCTAssertEqual(width(CGSize(width: 519, height: 1283), .pad), room, "Half a 13-inch screen")
		XCTAssertEqual(width(CGSize(width: 452, height: 520), .pad), 452, "A window narrower than the room fills it")
		XCTAssertNil(width(CGSize(width: 375, height: 1317), .pad), "A phone-sized third keeps the whole window")
	}

	private func width(_ window: CGSize, _ idiom: UIUserInterfaceIdiom) -> CGFloat? {
		PersonEditModeScene.columnWidth(layout: PersonPageLayout(window: window), window: window, insets: EdgeInsets(), idiom: idiom)
	}
}
