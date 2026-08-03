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

	func testAddSavesImagesBeforeCoreData() async throws {
		let parameters = parameters(appImage: PersonImage(uiImage: UIImage()), widgetImage: PersonImage(uiImage: UIImage()))
		let expectedPerson = Person.createPerson()
		coreDataGatewaySpy.addPersonResultToBeReturned = .success(expectedPerson)
		var events = [String]()
		imageStoreSpy.onSave = { events.append("save") }
		coreDataGatewaySpy.onAdd = { events.append("database") }

		let person = try await sut.add(parameters: parameters)
		XCTAssertEqual(person, expectedPerson)
		XCTAssertEqual(events, ["save", "save", "database"])
	}

	func testAddRollsBackPartialImageSaveAndSkipsCoreData() async {
		let parameters = parameters(appImage: PersonImage(uiImage: UIImage()), widgetImage: PersonImage(uiImage: UIImage()))
		imageStoreSpy.saveErrorAtCall = 2

		do {
			_ = try await sut.add(parameters: parameters)
			XCTFail("Expected image save failure")
		} catch {
			XCTAssertFalse(coreDataGatewaySpy.addPersonCalled)
			XCTAssertEqual(imageStoreSpy.deletedImages.map(\.id), imageStoreSpy.savedImages.map(\.id))
		}
	}

	func testEditCommitsNewImageBeforeDeletingReplacedImage() async throws {
		let oldAppID = UUID()
		let person = person(appPicID: oldAppID, widgetPicID: nil)
		let newAppImage = PersonImage(uiImage: UIImage())
		let parameters = parameters(appImage: newAppImage, widgetImage: nil)
		coreDataGatewaySpy.editPersonResultToBeReturned = .success(person)
		var events = [String]()
		imageStoreSpy.onSave = { events.append("save") }
		coreDataGatewaySpy.onEdit = { events.append("database") }
		imageStoreSpy.onDelete = { events.append("delete") }

		_ = try await sut.edit(person: person, with: parameters)
		XCTAssertEqual(events, ["save", "database", "delete"])
		XCTAssertEqual(imageStoreSpy.deletedImages.map(\.id), [oldAppID])
	}

	func testEditRollsBackNewImageWhenCoreDataFails() async {
		let oldAppID = UUID()
		let person = person(appPicID: oldAppID, widgetPicID: nil)
		let newAppImage = PersonImage(uiImage: UIImage())
		coreDataGatewaySpy.editPersonResultToBeReturned = .failure(.coreDataSaveFailed)

		do {
			_ = try await sut.edit(person: person, with: parameters(appImage: newAppImage, widgetImage: nil))
			XCTFail("Expected Core Data failure")
		} catch {
			XCTAssertEqual(error as? CoreError, .coreDataSaveFailed)
			XCTAssertEqual(imageStoreSpy.deletedImages.map(\.id), [newAppImage.id])
			XCTAssertFalse(imageStoreSpy.deletedImages.map(\.id).contains(oldAppID))
		}
	}

	func testRemoveReportsCoreDataSuccessAfterBestEffortImageCleanup() async throws {
		let person = Person.createPerson()
		coreDataGatewaySpy.removePersonResultToBeReturned = .success(())
		imageStoreSpy.deleteError = CoreError.unknownError
		var events = [String]()
		coreDataGatewaySpy.onRemove = { events.append("database") }
		imageStoreSpy.onDelete = { events.append("delete") }

		try await sut.remove(person: person)
		XCTAssertEqual(events, ["database", "delete", "delete"])
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
