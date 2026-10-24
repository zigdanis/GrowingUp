import XCTest

@testable import Core
@testable import GrowingUp

/// The stored mosaic order: new people join the end, and a reorder sets everyone's place.
final class CoreDataPersonsOrderTests: XCTestCase {
	private let gateway = CoreDataPersonsGateway(coreDataStack: InMemoryCoreDataStack())

	func test_Order_NewPeopleJoinTheEndOfTheMosaic() async throws {
		let added = try await addPeople(["Ada", "Ben", "Cleo"], to: gateway)
		XCTAssertEqual(added.map(\.displayOrder), [1, 2, 3])
		let fetched = try await gateway.fetchPersons()
		XCTAssertEqual(fetched.map(\.name), ["Ada", "Ben", "Cleo"])
	}

	func test_Order_ReorderIsStoredForTheMosaicAndTheWidget() async throws {
		let people = try await addPeople(["Ada", "Ben", "Cleo"], to: gateway)
		try await gateway.reorder([people[2].id, people[0].id, people[1].id])
		let fetched = try await gateway.fetchPersons()
		XCTAssertEqual(fetched.map(\.name), ["Cleo", "Ada", "Ben"])
		XCTAssertEqual(fetched.map(\.displayOrder), [1, 2, 3])
		let pinned = try await gateway.fetchWidgetPersons()
		XCTAssertEqual(pinned.map(\.name), ["Cleo", "Ada", "Ben"], "The widget follows the mosaic order")
		let added = try await gateway.add(parameters: named("Dan"))
		XCTAssertEqual(added.displayOrder, 4)
		let afterAdd = try await gateway.fetchPersons()
		XCTAssertEqual(afterAdd.map(\.name), ["Cleo", "Ada", "Ben", "Dan"])
		var edit = named("Ada Lovelace")
		edit.isOnWidget = true
		_ = try await gateway.edit(person: fetched[1], with: edit)
		let afterEdit = try await gateway.fetchPersons()
		XCTAssertEqual(afterEdit.map(\.name), ["Cleo", "Ada Lovelace", "Ben", "Dan"], "An edit keeps the person's place")
	}

	func test_Order_PeopleMissingFromAReorderFollowInTheirOrder() async throws {
		let people = try await addPeople(["Ada", "Ben", "Cleo"], to: gateway)
		try await gateway.reorder([people[2].id])
		let fetched = try await gateway.fetchPersons()
		XCTAssertEqual(fetched.map(\.name), ["Cleo", "Ada", "Ben"])
		XCTAssertEqual(fetched.map(\.displayOrder), [1, 2, 3])
	}

	func test_Order_RemovalKeepsTheOthersInOrder() async throws {
		let people = try await addPeople(["Ada", "Ben", "Cleo"], to: gateway)
		try await gateway.reorder([people[2].id, people[0].id, people[1].id])
		try await gateway.remove(person: people[0])
		_ = try await gateway.add(parameters: named("Dan"))
		let fetched = try await gateway.fetchPersons()
		XCTAssertEqual(fetched.map(\.name), ["Cleo", "Ben", "Dan"])
	}

	func test_Order_UnknownPersonFailsTheWholeReorder() async throws {
		let people = try await addPeople(["Ada", "Ben", "Cleo"], to: gateway)
		do {
			try await gateway.reorder([people[1].id, UUID(), people[0].id])
			XCTFail("An unknown person must not be stored")
		} catch {
			XCTAssertEqual(error as? CoreError, .coreDataFetchFailed)
		}
		let fetched = try await gateway.fetchPersons()
		XCTAssertEqual(fetched.map(\.name), ["Ada", "Ben", "Cleo"])
		XCTAssertEqual(fetched.map(\.displayOrder), [1, 2, 3])
	}

	private func addPeople(_ names: [String], to gateway: CoreDataPersonsGateway) async throws -> [Person] {
		var people: [Person] = []
		for name in names {
			people.append(try await gateway.add(parameters: named(name)))
		}
		return people
	}

	private func named(_ name: String) -> AddPersonParameters {
		var parameters = AddPersonParameters.createParameters()
		parameters.name = name
		return parameters
	}
}
