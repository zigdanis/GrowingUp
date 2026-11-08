import XCTest

@testable import Core

final class PhotoFileNameTests: XCTestCase {
	func testPhotoFileNames() {
		let id = UUID()
		XCTAssertEqual(PhotoFileName.id(of: "\(id.uuidString).png"), id)
		XCTAssertEqual(PhotoFileName.id(of: "\(id.uuidString).HEIC"), id)
		XCTAssertEqual(PhotoFileName.id(of: "\(id.uuidString).jpg"), id)
		XCTAssertNil(PhotoFileName.id(of: "\(id.uuidString).sqlite"))
		XCTAssertNil(PhotoFileName.id(of: "cover.png"))
	}
}
