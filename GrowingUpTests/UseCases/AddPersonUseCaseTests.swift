import XCTest

@testable import Core
@testable import GrowingUp

final class AddPersonUseCaseTests: XCTestCase {

	func testAddPassesParametersAndReturnsPerson() async throws {
		let gateway = PersonsGatewaySpy()
		let sut = AddPersonUseCaseImplementation(personsGateway: gateway)
		let parameters = AddPersonParameters.createParameters()
		let expectedPerson = Person.createPerson()
		gateway.addPersonResultToBeReturned = .success(expectedPerson)

		let person = try await sut.add(parameters: parameters)

		XCTAssertEqual(person, expectedPerson)
		XCTAssertEqual(gateway.addPersonParameters, parameters)
	}
}
