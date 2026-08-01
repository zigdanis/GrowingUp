//
//  CachePersonsGatewayTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 06/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import XCTest

@testable import Core
@testable import GrowingUp

final class CachePersonsGatewayTests: XCTestCase {

	private var sut: CachePersonsGateway!
	private let coreDataGatewaySpy = PersonsGatewaySpy()
	private let imageStoreSpy = ImageStoreSpy()

	override func setUp() {
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, imageStore: imageStoreSpy)
	}

	func testAddSavesImagesBeforeCoreData() {
		let parameters = parameters(appImage: PersonImage(uiImage: UIImage()), widgetImage: PersonImage(uiImage: UIImage()))
		let expectedPerson = Person.createPerson()
		coreDataGatewaySpy.addPersonResultToBeReturned = .success(expectedPerson)
		var events = [String]()
		imageStoreSpy.onSave = { events.append("save") }
		coreDataGatewaySpy.onAdd = { events.append("database") }
		let completed = expectation(description: "add completes")

		sut.add(parameters: parameters) { result in
			XCTAssertEqual(result, .success(expectedPerson))
			XCTAssertEqual(events, ["save", "save", "database"])
			completed.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	func testAddRollsBackPartialImageSaveAndSkipsCoreData() {
		let parameters = parameters(appImage: PersonImage(uiImage: UIImage()), widgetImage: PersonImage(uiImage: UIImage()))
		imageStoreSpy.saveErrorAtCall = 2
		let completed = expectation(description: "add fails")

		sut.add(parameters: parameters) { result in
			guard case .failure = result else {
				return XCTFail("Expected image save failure")
			}
			XCTAssertFalse(self.coreDataGatewaySpy.addPersonCalled)
			XCTAssertEqual(self.imageStoreSpy.deletedImages.map(\.id), self.imageStoreSpy.savedImages.map(\.id))
			completed.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	func testEditCommitsNewImageBeforeDeletingReplacedImage() {
		let oldAppID = UUID()
		let person = person(appPicID: oldAppID, widgetPicID: nil)
		let newAppImage = PersonImage(uiImage: UIImage())
		let parameters = parameters(appImage: newAppImage, widgetImage: nil)
		coreDataGatewaySpy.editPersonResultToBeReturned = .success(person)
		var events = [String]()
		imageStoreSpy.onSave = { events.append("save") }
		coreDataGatewaySpy.onEdit = { events.append("database") }
		imageStoreSpy.onDelete = { events.append("delete") }
		let completed = expectation(description: "edit completes")

		sut.edit(person: person, with: parameters) { _ in
			XCTAssertEqual(events, ["save", "database", "delete"])
			XCTAssertEqual(self.imageStoreSpy.deletedImages.map(\.id), [oldAppID])
			completed.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	func testEditRollsBackNewImageWhenCoreDataFails() {
		let oldAppID = UUID()
		let person = person(appPicID: oldAppID, widgetPicID: nil)
		let newAppImage = PersonImage(uiImage: UIImage())
		coreDataGatewaySpy.editPersonResultToBeReturned = .failure(.coreDataSaveFailed)
		let completed = expectation(description: "edit fails")

		sut.edit(person: person, with: parameters(appImage: newAppImage, widgetImage: nil)) { result in
			XCTAssertEqual(result, .failure(.coreDataSaveFailed))
			XCTAssertEqual(self.imageStoreSpy.deletedImages.map(\.id), [newAppImage.id])
			XCTAssertFalse(self.imageStoreSpy.deletedImages.map(\.id).contains(oldAppID))
			completed.fulfill()
		}

		waitForExpectations(timeout: 1)
	}

	func testRemoveReportsCoreDataSuccessAfterBestEffortImageCleanup() {
		let person = Person.createPerson()
		coreDataGatewaySpy.removePersonResultToBeReturned = .success(())
		imageStoreSpy.deleteError = CoreError.unknownError
		var events = [String]()
		coreDataGatewaySpy.onRemove = { events.append("database") }
		imageStoreSpy.onDelete = { events.append("delete") }
		var completionCount = 0
		let completed = expectation(description: "remove completes")

		sut.remove(person: person) { result in
			completionCount += 1
			if case .failure(let error) = result {
				XCTFail("Expected success, got \(error)")
			}
			XCTAssertEqual(events, ["database", "delete", "delete"])
			completed.fulfill()
		}

		waitForExpectations(timeout: 1)
		XCTAssertEqual(completionCount, 1)
	}

	func testAsyncAddHonorsCancellationBeforeSideEffects() async {
		let operation = Task {
			try await sut.add(parameters: parameters(appImage: PersonImage(uiImage: UIImage()), widgetImage: nil))
		}
		operation.cancel()

		do {
			_ = try await operation.value
			XCTFail("Expected cancellation")
		} catch is CancellationError {
			XCTAssertTrue(imageStoreSpy.savedImages.isEmpty)
			XCTAssertFalse(coreDataGatewaySpy.addPersonCalled)
		} catch {
			XCTFail("Expected CancellationError, got \(error)")
		}
	}

	private func parameters(appImage: PersonImage?, widgetImage: PersonImage?) -> AddPersonParameters {
		AddPersonParameters(
			name: "John", dayOfBirth: Date(), timeOfBirth: Date(),
			appImage: appImage, widgetImage: widgetImage, isOnWidget: false)
	}

	private func person(appPicID: UUID?, widgetPicID: UUID?) -> Person {
		Person(
			id: UUID(), name: "John", birthday: Date(), appPicId: appPicID, widgetPicId: widgetPicID,
			isOnWidget: false, createdDate: Date())
	}
}
