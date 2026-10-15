import Core
import UIKit
import XCTest

@testable import GrowingUp

final class WidgetPersonLoaderTests: XCTestCase {
	func testFirstPinnedPersonInCreationOrderHasTheFirstDeepLinkIndex() async {
		let people = pinnedPeople(count: 3)
		let useCase = FetchPersonsUseCaseSpy()
		useCase.completionResult = .success(people.reversed())
		var requestedImages: [UUID] = []
		let loader = WidgetPersonLoader(
			fetch: { try await useCase.fetchWidgetPersons() },
			loadImage: { image in
				requestedImages.append(image.id)
				return UIImage()
			})
		let first = await loader.loadFirst()
		XCTAssertEqual(first?.id, people[0].id)
		XCTAssertEqual(first?.index, 0)
		XCTAssertEqual(first?.name, people[0].name)
		XCTAssertEqual(first?.birthday, people[0].birthday)
		XCTAssertNotNil(first?.image)
		XCTAssertEqual(requestedImages, [people[0].widgetPicId].compactMap { $0 })
		let two = await loader.load(limit: 2)
		XCTAssertEqual(two.map(\.id), people.prefix(2).map(\.id))
		XCTAssertEqual(two.map(\.index), [0, 1])
		XCTAssertEqual(two.map(\.deepLinkURL.absoluteString), ["growingup-app://?personIndex=0", "growingup-app://?personIndex=1"])
	}

	func testNobodyPinnedOrFailedFetchLoadsNobody() async {
		let useCase = FetchPersonsUseCaseSpy()
		useCase.completionResult = .success([])
		let empty = WidgetPersonLoader(fetch: { try await useCase.fetchWidgetPersons() }, loadImage: { _ in UIImage() })
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
		XCTAssertNil(persons[0].image)
		XCTAssertNil(persons[1].image)
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
