import XCTest

@testable import Core

final class FetchPersonsUseCaseTests: XCTestCase {

	func testFetchReturnsPersons() async throws {
		let gateway = PersonsGatewaySpy()
		let sut = FetchPersonsUseCaseImplementation(personsGateway: gateway)
		let expectedPersons = [Person.createPerson()]
		gateway.fetchPersonsResultToBeReturned = .success(expectedPersons)

		let persons = try await sut.fetchPersons()
		XCTAssertEqual(persons, expectedPersons)
		XCTAssertTrue(gateway.fetchPersonsCalled)
	}

	func testFetchPropagatesError() async {
		let gateway = PersonsGatewaySpy()
		let sut = FetchPersonsUseCaseImplementation(personsGateway: gateway)
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)

		do {
			_ = try await sut.fetchPersons()
			XCTFail("Expected fetch failure")
		} catch {
			XCTAssertEqual(error as? CoreError, .coreDataFetchFailed)
		}
	}
}
