import XCTest

@testable import GrowingUp

final class PersonPageLayoutTests: XCTestCase {
	func testEveryIPhoneAndNarrowWindowKeepsThePhoneLayout() {
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 440, height: 956)), .phone)
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 402, height: 874)), .phone)
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 449, height: 700)), .phone)
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 320, height: 951)), .phone)
	}

	func testWideUprightWindowsGetTheCenteredColumn() {
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 466, height: 678)), .widePortrait)
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 669, height: 951)), .widePortrait)
	}

	func testWindowsAtLeastAsWideAsTallGetTwoPanes() {
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 951, height: 669)), .landscape)
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 678, height: 466)), .landscape)
	}

	func testOnlyWiderLayoutsCapTheContentColumn() {
		XCTAssertNil(PersonPageLayout.phone.columnWidth)
		XCTAssertEqual(PersonPageLayout.widePortrait.columnWidth, 600)
		XCTAssertEqual(PersonPageLayout.landscape.columnWidth, 480)
	}

	func testAnUnmeasuredWindowStartsAsAPhone() {
		XCTAssertEqual(PersonPageLayout(window: .zero), .phone)
	}

	func testIPadWindowsTakeTheSameLayoutsByShape() {
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 1032, height: 1376)), .widePortrait, "13-inch portrait")
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 1376, height: 1032)), .landscape, "13-inch landscape")
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 744, height: 1133)), .widePortrait, "mini portrait")
		XCTAssertEqual(PersonPageLayout(window: CGSize(width: 375, height: 1032)), .phone, "A narrow Split View window")
	}

	func testOnlyAPhonesWideWindowsSpanAFold() {
		XCTAssertFalse(PersonPageLayout.phone.spansFold(idiom: .phone))
		XCTAssertTrue(PersonPageLayout.widePortrait.spansFold(idiom: .phone), "iPhone Duo upright")
		XCTAssertTrue(PersonPageLayout.landscape.spansFold(idiom: .phone), "iPhone Duo unfolded")
		for layout in [PersonPageLayout.phone, .widePortrait, .landscape] {
			XCTAssertFalse(layout.spansFold(idiom: .pad), "\(layout) on iPad")
		}
	}
}
