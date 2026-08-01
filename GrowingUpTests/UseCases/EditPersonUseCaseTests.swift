import XCTest

@testable import Core

final class EditPersonUseCaseTests: XCTestCase {

	func testEditPassesParametersAndReturnsPerson() async throws {
		let gateway = PersonsGatewaySpy()
		let sut = EditPersonUseCaseImplementation(personsGateway: gateway)
		let person = Person.createPerson()
		let parameters = AddPersonParameters.createParameters()
		gateway.editPersonResultToBeReturned = .success(person)

		XCTAssertEqual(try await sut.edit(person: person, with: parameters), person)
		XCTAssertEqual(gateway.addPersonParameters, parameters)
	}
}
