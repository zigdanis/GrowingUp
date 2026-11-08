import CoreData
import UIKit
import XCTest

@testable import Core
@testable import GrowingUp

final class WidgetPersonLoaderTests: XCTestCase {
	/// A real picture: the person's `photo` is drawn from it, which an empty `UIImage` cannot be.
	private static let photo = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
		UIColor.orange.setFill()
		context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
	}

	private var directory: URL!

	override func setUpWithError() throws {
		directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: directory)
	}

	func testFirstPinnedPersonInCreationOrderHasStableDeepLink() async throws {
		let people = pinnedPeople(count: 3)
		let useCase = FetchPersonsUseCaseSpy()
		useCase.completionResult = .success(people.reversed())
		var requestedImages: [UUID] = []
		let loader = WidgetPersonLoader(
			fetch: { try await useCase.fetchWidgetPersons() },
			loadImage: { image in
				requestedImages.append(image.id)
				return Self.photo
			})
		let first = await loader.loadFirst().value
		XCTAssertEqual(first?.id, people[0].id)
		XCTAssertEqual(first?.index, 0)
		XCTAssertEqual(first?.name, people[0].name)
		XCTAssertEqual(first?.birthday, people[0].birthday)
		XCTAssertNotNil(first?.photo)
		XCTAssertEqual(requestedImages, [people[0].widgetPicId].compactMap { $0 })
		let loadedTwo = await loader.load(limit: 2)
		let two = try XCTUnwrap(loadedTwo.value)
		XCTAssertEqual(two.map(\.id), people.prefix(2).map(\.id))
		XCTAssertEqual(two.map(\.index), [0, 1])
		XCTAssertEqual(
			two.map(\.deepLinkURL.absoluteString),
			people.prefix(2).map { "growingup-app://?personID=\($0.id.uuidString)" })
	}

	func testPinnedPeopleFollowTheMosaicOrder() async throws {
		var people = pinnedPeople(count: 3)
		// Reordered: the last created person moved first, and the rest follow in the stored order.
		people[2].displayOrder = 1
		people[0].displayOrder = 2
		people[1].displayOrder = 3
		let loader = WidgetPersonLoader(fetch: { people }, loadImage: { _ in Self.photo })
		let loaded = await loader.load(limit: Constants.widgetPeopleLimit)
		let persons = try XCTUnwrap(loaded.value)
		XCTAssertEqual(persons.map(\.id), [people[2].id, people[0].id, people[1].id])
		XCTAssertEqual(persons.map(\.index), [0, 1, 2])
		let first = await loader.loadFirst().value
		XCTAssertEqual(first?.id, people[2].id, "The Lock Screen shows the first pinned person in mosaic order")
	}

	func testNobodyPinnedIsAConfirmedAbsence() async {
		let useCase = FetchPersonsUseCaseSpy()
		useCase.completionResult = .success([])
		let loader = WidgetPersonLoader(fetch: { try await useCase.fetchWidgetPersons() }, loadImage: { _ in Self.photo })
		let people = await loader.load(limit: Constants.widgetPeopleLimit)
		let first = await loader.loadFirst()
		XCTAssertTrue(Self.isNobodyPinned(people))
		XCTAssertTrue(Self.isNobodyPinned(first))
	}

	func testFailedFetchIsUnavailableRatherThanNobodyPinned() async {
		let useCase = FetchPersonsUseCaseSpy()
		useCase.completionResult = .failure(.coreDataFetchFailed)
		let loader = WidgetPersonLoader(fetch: { try await useCase.fetchWidgetPersons() }, loadImage: { _ in Self.photo })
		let people = await loader.load(limit: Constants.widgetPeopleLimit)
		let first = await loader.loadFirst()
		XCTAssertTrue(Self.isUnavailable(people))
		XCTAssertTrue(Self.isUnavailable(first))
	}

	func testPhotoFailureKeepsThePersonWithoutPhoto() async throws {
		var withoutPhoto = Person.createPerson()
		withoutPhoto.widgetPicId = nil
		withoutPhoto.createdDate = Date(timeIntervalSince1970: 1)
		withoutPhoto.isOnWidget = true
		let people = pinnedPeople(count: 1) + [withoutPhoto]
		let loader = WidgetPersonLoader(fetch: { people }, loadImage: { _ in throw CoreError.missingValue })
		let loaded = await loader.load(limit: Constants.widgetPeopleLimit)
		let persons = try XCTUnwrap(loaded.value)
		XCTAssertEqual(persons.map(\.id), people.map(\.id))
		XCTAssertNil(persons[0].photo)
		XCTAssertNil(persons[1].photo)
	}

	func testLockedOrUnreadableStoreIsUnavailable() async {
		// Before the first unlock the protected store cannot be opened; an I/O error or a missing App Group fails alike.
		let failures: [Error] = [
			CocoaError(.fileReadNoPermission),
			CocoaError(.fileReadUnknown),
			NSError(domain: NSPOSIXErrorDomain, code: Int(EIO)),
			CoreError(message: "Failed to get App Group URL")
		]
		for failure in failures {
			let stack = CoreDataStackImplementation(makeContainer: { throw failure })
			let gateway = CoreDataPersonsGateway(coreDataStack: stack)
			let loader = WidgetPersonLoader(fetch: { try await gateway.fetchWidgetPersons() }, loadImage: { _ in Self.photo })
			let people = await loader.load(limit: Constants.widgetPeopleLimit)
			let first = await loader.loadFirst()
			XCTAssertTrue(Self.isUnavailable(people), "\(failure)")
			XCTAssertTrue(Self.isUnavailable(first), "\(failure)")
		}
	}

	/// A fresh store has no people and no widget record yet: that is nobody pinned, not a failure.
	func testColdStartWithFreshStoreIsNobodyPinned() async throws {
		let stack = CoreDataStackImplementation(makeContainer: makeContainer)
		let gateway = CoreDataPersonsGateway(coreDataStack: stack)
		let loader = WidgetPersonLoader(fetch: { try await gateway.fetchWidgetPersons() }, loadImage: { _ in Self.photo })
		let people = await loader.load(limit: Constants.widgetPeopleLimit)
		XCTAssertTrue(Self.isNobodyPinned(people))
		close(try stack.persistentContainer)
	}

	/// The stack keeps no failure, so the first attempt after the store becomes readable finds the pinned people.
	func testStoreThatBecomesReadableLoadsPeopleOnTheNextAttempt() async throws {
		var isLocked = true
		let stack = CoreDataStackImplementation(makeContainer: makeContainer) { container in
			if isLocked { throw CocoaError(.fileReadNoPermission) }
			try CoreDataStackImplementation.loadPersistentStores(container)
		}
		let gateway = CoreDataPersonsGateway(coreDataStack: stack)
		let loader = WidgetPersonLoader(fetch: { try await gateway.fetchWidgetPersons() }, loadImage: { _ in Self.photo })
		let locked = await loader.loadFirst()
		XCTAssertTrue(Self.isUnavailable(locked))
		isLocked = false
		let added = try await gateway.add(parameters: .createParameters())
		let unlocked = await loader.loadFirst()
		XCTAssertEqual(unlocked.value?.id, added.id)
		close(try stack.persistentContainer)
	}

	private func pinnedPeople(count: Int) -> [Person] {
		(0..<count).map { index in
			var person = Person.createPerson()
			person.name = "Person \(index)"
			person.isOnWidget = true
			person.createdDate = Date(timeIntervalSince1970: Double(index))
			return person
		}
	}

	/// A container for an SQLite store in this test's own directory.
	private func makeContainer() throws -> NSPersistentContainer {
		let modelURL = try XCTUnwrap(Bundle(for: CoreDataPerson.self).url(forResource: "GrowingUp", withExtension: "momd"))
		let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
		let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
		container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: directory.appendingPathComponent("GrowingUp.sqlite"))]
		return container
	}

	private func close(_ container: NSPersistentContainer) {
		for store in container.persistentStoreCoordinator.persistentStores {
			try? container.persistentStoreCoordinator.remove(store)
		}
	}

	private static func isNobodyPinned<Value>(_ result: WidgetLoadResult<Value>) -> Bool {
		if case .nobodyPinned = result { true } else { false }
	}

	private static func isUnavailable<Value>(_ result: WidgetLoadResult<Value>) -> Bool {
		if case .unavailable = result { true } else { false }
	}
}
