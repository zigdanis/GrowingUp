import XCTest

@testable import Core

final class ReorderPersonsUseCaseTests: XCTestCase {

	func testReorderPassesTheOrderToTheGateway() async throws {
		let gateway = PersonsGatewaySpy()
		let sut = ReorderPersonsUseCaseImplementation(personsGateway: gateway)
		let order = [UUID(), UUID()]

		try await sut.reorder(order)

		XCTAssertEqual(gateway.reorderedIDs, [order])
	}

	func testReorderRethrowsTheGatewayError() async {
		let gateway = PersonsGatewaySpy()
		gateway.reorderResultToBeReturned = .failure(.coreDataSaveFailed)
		let sut = ReorderPersonsUseCaseImplementation(personsGateway: gateway)

		do {
			try await sut.reorder([UUID()])
			XCTFail("The gateway's failure must reach the caller")
		} catch {
			XCTAssertEqual(error as? CoreError, .coreDataSaveFailed)
		}
	}
}
