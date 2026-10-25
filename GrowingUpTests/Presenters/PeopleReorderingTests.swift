import Core
import XCTest

@testable import GrowingUp

@MainActor
final class PeopleReorderingTests: XCTestCase {
	func testReorderingStartsAndFinishesAndTilesOpenNothingMeanwhile() async {
		let people = makePeople(count: 3)
		let (presenter, _) = await loadedPresenter(people)
		XCTAssertFalse(presenter.isReordering)
		presenter.startReordering()
		XCTAssertTrue(presenter.isReordering)
		presenter.view(people[1].id)
		XCTAssertFalse(presenter.isViewing, "A tile tap while reordering opens nothing")
		XCTAssertNil(presenter.selectedID)
		presenter.finishReordering()
		XCTAssertFalse(presenter.isReordering)
		presenter.view(people[1].id)
		XCTAssertTrue(presenter.isViewing)
	}

	func testAnEmptyMosaicCannotReorder() async {
		let (presenter, _) = await loadedPresenter([])
		presenter.startReordering()
		XCTAssertFalse(presenter.isReordering)
	}

	func testMovesOnlyWhileReorderingAndClampToTheMosaic() async {
		let people = makePeople(count: 3)
		let (presenter, _) = await loadedPresenter(people)
		presenter.move(people[0].id, to: 2)
		XCTAssertEqual(presenter.persons.map(\.id), people.map(\.id), "Moves need reordering")
		presenter.startReordering()
		presenter.move(people[0].id, to: 2)
		XCTAssertEqual(presenter.persons.map(\.id), [people[1].id, people[2].id, people[0].id])
		presenter.move(people[0].id, to: -5)
		XCTAssertEqual(presenter.persons.map(\.id), people.map(\.id))
		presenter.move(people[1].id, to: 99)
		XCTAssertEqual(presenter.persons.map(\.id), [people[0].id, people[2].id, people[1].id])
		presenter.move(UUID(), to: 0)
		XCTAssertEqual(presenter.persons.map(\.id), [people[0].id, people[2].id, people[1].id])
	}

	func testSavingStoresTheNewOrderAndReloadsWidgets() async {
		let people = makePeople(count: 3)
		var reloads = 0
		let (presenter, gateway) = await loadedPresenter(people, reloadWidgets: { reloads += 1 })
		presenter.startReordering()
		presenter.move(people[2].id, to: 0)
		await presenter.saveOrder()
		let order = [people[2].id, people[0].id, people[1].id]
		XCTAssertEqual(gateway.reorderedIDs, [order])
		XCTAssertEqual(presenter.persons.map(\.id), order)
		XCTAssertEqual(presenter.persons.map(\.displayOrder), [1, 2, 3])
		XCTAssertEqual(reloads, 1)
		XCTAssertNil(presenter.error)
		await presenter.saveOrder()
		XCTAssertEqual(gateway.reorderedIDs.count, 1, "An unchanged order is not stored again")
	}

	func testADropInPlaceStoresNothing() async {
		let people = makePeople(count: 3)
		let (presenter, gateway) = await loadedPresenter(people)
		presenter.startReordering()
		presenter.move(people[0].id, to: 2)
		presenter.move(people[0].id, to: 0)
		await presenter.saveOrder()
		XCTAssertTrue(gateway.reorderedIDs.isEmpty)
	}

	func testAFailedSaveRestoresTheStoredOrderAndShowsTheError() async {
		let people = makePeople(count: 3)
		let (presenter, gateway) = await loadedPresenter(people)
		gateway.reorderResultToBeReturned = .failure(.coreDataSaveFailed)
		presenter.startReordering()
		presenter.move(people[0].id, to: 2)
		await presenter.saveOrder()
		XCTAssertEqual(presenter.persons.map(\.id), people.map(\.id))
		XCTAssertEqual(presenter.persons.map(\.displayOrder), [0, 0, 0])
		XCTAssertEqual(presenter.error?.message, CoreError.coreDataSaveFailed.message)
		XCTAssertTrue(presenter.isReordering, "The mosaic stays in reordering to try again")
	}

	func testAFailedSaveThatANewerOneSupersededNeitherRollsBackNorShowsAnError() async {
		let people = makePeople(count: 3)
		let (presenter, gateway) = await loadedPresenter(people)
		presenter.startReordering()
		var releaseFirst: CheckedContinuation<Void, Never>?
		gateway.onReorder = {
			guard gateway.reorderedIDs.count == 1 else { return }
			await withCheckedContinuation { releaseFirst = $0 }
		}
		gateway.reorderResultToBeReturned = .failure(.coreDataSaveFailed)
		presenter.move(people[2].id, to: 0)
		let first = Task { await presenter.saveOrder() }
		while releaseFirst == nil { await Task.yield() }
		presenter.move(people[1].id, to: 0)
		let second = Task { await presenter.saveOrder() }
		for _ in 0..<20 { await Task.yield() }
		releaseFirst?.resume()
		await first.value
		gateway.reorderResultToBeReturned = .success(())
		await second.value
		XCTAssertEqual(presenter.persons.map(\.id), [people[1].id, people[2].id, people[0].id])
		XCTAssertNil(presenter.error)
	}

	func testAFailedSaveRestoresTheLastStoredOrderWhateverWasSavedBefore() async {
		let people = makePeople(count: 3)
		let (presenter, gateway) = await loadedPresenter(people)
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)
		presenter.startReordering()
		presenter.move(people[2].id, to: 0)
		await presenter.saveOrder()
		let stored = [people[2].id, people[0].id, people[1].id]
		gateway.reorderResultToBeReturned = .failure(.coreDataSaveFailed)
		presenter.move(people[1].id, to: 0)
		await presenter.saveOrder()
		XCTAssertEqual(presenter.persons.map(\.id), stored, "Nothing is read back: the stored order is known")
		XCTAssertEqual(presenter.persons.map(\.displayOrder), [1, 2, 3])
		XCTAssertEqual(presenter.error?.message, CoreError.coreDataSaveFailed.message)
	}

	func testAFailedSaveRestoresTheOrderStoredWhileItWaited() async {
		let people = makePeople(count: 3)
		let (presenter, gateway) = await loadedPresenter(people)
		presenter.startReordering()
		var releaseFirst: CheckedContinuation<Void, Never>?
		gateway.onReorder = {
			// The first save is held until the second waits behind it; the second then fails.
			if gateway.reorderedIDs.count == 1 {
				await withCheckedContinuation { releaseFirst = $0 }
			} else {
				gateway.reorderResultToBeReturned = .failure(.coreDataSaveFailed)
			}
		}
		presenter.move(people[2].id, to: 0)
		let first = Task { await presenter.saveOrder() }
		while releaseFirst == nil { await Task.yield() }
		presenter.move(people[1].id, to: 0)
		let second = Task { await presenter.saveOrder() }
		for _ in 0..<20 { await Task.yield() }
		releaseFirst?.resume()
		await second.value
		await first.value
		XCTAssertEqual(presenter.persons.map(\.id), [people[2].id, people[0].id, people[1].id], "The first save's order")
		XCTAssertEqual(presenter.persons.map(\.displayOrder), [1, 2, 3])
		XCTAssertEqual(presenter.error?.message, CoreError.coreDataSaveFailed.message)
	}

	func testSavesAreStoredInTheOrderTheyWereMade() async {
		let people = makePeople(count: 3)
		let (presenter, gateway) = await loadedPresenter(people)
		presenter.startReordering()
		var releaseFirst: CheckedContinuation<Void, Never>?
		gateway.onReorder = {
			guard gateway.reorderedIDs.count == 1 else { return }
			await withCheckedContinuation { releaseFirst = $0 }
		}
		presenter.move(people[2].id, to: 0)
		let first = Task { await presenter.saveOrder() }
		while releaseFirst == nil { await Task.yield() }
		presenter.move(people[1].id, to: 0)
		let second = Task { await presenter.saveOrder() }
		for _ in 0..<20 { await Task.yield() }
		XCTAssertEqual(gateway.reorderedIDs.count, 1, "The second save waits for the first")
		releaseFirst?.resume()
		await first.value
		await second.value
		XCTAssertEqual(
			gateway.reorderedIDs, [[people[2].id, people[0].id, people[1].id], [people[1].id, people[2].id, people[0].id]])
	}

	func testANewPersonJoinsTheEndOfAReorderedMosaic() async {
		let people = makePeople(count: 2)
		let (presenter, _) = await loadedPresenter(people)
		presenter.startReordering()
		presenter.move(people[1].id, to: 0)
		await presenter.saveOrder()
		presenter.finishReordering()
		var added = Person.createPerson()
		added.displayOrder = 3
		presenter.add()
		presenter.apply(.saved(added), from: presenter.editor)
		XCTAssertEqual(presenter.persons.map(\.id), [people[1].id, people[0].id, added.id])
	}

	func testLoadedPeopleFollowTheStoredOrder() async {
		var people = makePeople(count: 3)
		people[0].displayOrder = 3
		people[1].displayOrder = 1
		people[2].displayOrder = 2
		let (presenter, _) = await loadedPresenter(people)
		XCTAssertEqual(presenter.persons.map(\.id), [people[1].id, people[2].id, people[0].id])
	}

	func testWidgetIndexLinksFollowTheMosaicOrderOfPinnedPeople() async {
		var people = makePeople(count: 3)
		for index in people.indices { people[index].isOnWidget = true }
		people[2].displayOrder = 1
		people[0].displayOrder = 2
		people[1].displayOrder = 3
		let (presenter, _) = await loadedPresenter(people)
		presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIndexKey)=0")!)
		XCTAssertEqual(presenter.selectedID, people[2].id)
	}

	func testAWidgetLinkEndsReorderingAndOpensThePerson() async {
		let people = makePeople(count: 2)
		let (presenter, _) = await loadedPresenter(people)
		presenter.startReordering()
		presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIDKey)=\(people[1].id.uuidString)")!)
		XCTAssertFalse(presenter.isReordering)
		XCTAssertTrue(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, people[1].id)
		presenter.closeViewer()
		presenter.startReordering()
		presenter.open(URL(string: "growingup-app://\(Constants.widgetAddPersonHost)")!)
		XCTAssertFalse(presenter.isReordering)
		XCTAssertNotNil(presenter.editor)
	}

	private func loadedPresenter(
		_ people: [Person], reloadWidgets: @escaping () -> Void = {}
	) async -> (PeoplePresenter, PersonsGatewaySpy) {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: reloadWidgets)
		await presenter.load()
		return (presenter, gateway)
	}

	private func makePeople(count: Int) -> [Person] {
		(0..<count).map { index in
			var person = Person.createPerson()
			person.createdDate = Date(timeIntervalSince1970: Double(index))
			return person
		}
	}
}
