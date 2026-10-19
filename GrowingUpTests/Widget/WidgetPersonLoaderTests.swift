import Core
import UIKit
import XCTest

@testable import GrowingUp

final class WidgetPersonLoaderTests: XCTestCase {
	/// A real picture: the person's `photo` is drawn from it, which an empty `UIImage` cannot be.
	private static let photo = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
		UIColor.orange.setFill()
		context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
	}

	func testFirstPinnedPersonInCreationOrderHasStableDeepLink() async {
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
		let first = await loader.loadFirst()
		XCTAssertEqual(first?.id, people[0].id)
		XCTAssertEqual(first?.index, 0)
		XCTAssertEqual(first?.name, people[0].name)
		XCTAssertEqual(first?.birthday, people[0].birthday)
		XCTAssertNotNil(first?.photo)
		XCTAssertEqual(requestedImages, [people[0].widgetPicId].compactMap { $0 })
		let two = await loader.load(limit: 2)
		XCTAssertEqual(two.map(\.id), people.prefix(2).map(\.id))
		XCTAssertEqual(two.map(\.index), [0, 1])
		XCTAssertEqual(
			two.map(\.deepLinkURL.absoluteString),
			people.prefix(2).map { "growingup-app://?personID=\($0.id.uuidString)" })
	}

	func testNobodyPinnedOrFailedFetchLoadsNobody() async {
		let useCase = FetchPersonsUseCaseSpy()
		useCase.completionResult = .success([])
		let empty = WidgetPersonLoader(fetch: { try await useCase.fetchWidgetPersons() }, loadImage: { _ in Self.photo })
		let nobody = await empty.loadFirst()
		XCTAssertNil(nobody)
		useCase.completionResult = .failure(.coreDataFetchFailed)
		let failed = await empty.load(limit: Constants.widgetPeopleLimit)
		XCTAssertTrue(failed.isEmpty)
	}

	func testPhotoFailureKeepsThePersonWithoutPhoto() async {
		var withoutPhoto = Person.createPerson()
		withoutPhoto.widgetPicId = nil
		withoutPhoto.createdDate = Date(timeIntervalSince1970: 1)
		withoutPhoto.isOnWidget = true
		let people = pinnedPeople(count: 1) + [withoutPhoto]
		let loader = WidgetPersonLoader(fetch: { people }, loadImage: { _ in throw CoreError.missingValue })
		let persons = await loader.load(limit: Constants.widgetPeopleLimit)
		XCTAssertEqual(persons.map(\.id), people.map(\.id))
		XCTAssertNil(persons[0].photo)
		XCTAssertNil(persons[1].photo)
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
}
