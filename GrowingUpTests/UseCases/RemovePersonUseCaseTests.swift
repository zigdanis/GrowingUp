import XCTest

@testable import Core

final class RemovePersonUseCaseTests: XCTestCase {

	func testRemoveCallsGateway() async throws {
		let gateway = PersonsGatewaySpy()
		let sut = RemovePersonUseCaseImplementation(personsGateway: gateway)
		gateway.removePersonResultToBeReturned = .success(())

		try await sut.remove(person: Person.createPerson())

		XCTAssertTrue(gateway.removePersonCalled)
	}
}
