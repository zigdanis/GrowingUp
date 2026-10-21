import XCTest

@testable import GrowingUp

final class PeoplePageIDTests: XCTestCase {
	func testAPersonSelectionShowsThatPersonsPage() {
		let id = UUID()
		XCTAssertEqual(PeoplePageID(selectedID: id), .person(id))
		XCTAssertEqual(PeoplePageID.person(id).selectedID, id)
	}

	func testNoSelectedPersonShowsTheAddPage() {
		XCTAssertEqual(PeoplePageID(selectedID: nil), .add)
		XCTAssertNil(PeoplePageID.add.selectedID)
	}
}
