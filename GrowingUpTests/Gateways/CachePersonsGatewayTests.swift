//
//  CachePersonsGatewayTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 06/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp
@testable import Core

class CachePersonsGatewayTests: XCTestCase {

	var sut: CachePersonsGateway!
	let coreDataGatewaySpy = PersonsGatewaySpy()
	let taskManagerSpy = TaskManagerSpy()

    override func setUp() {
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManagerSpy)
    }

	func test_SUT_WhenAddingPerson_CallingTaskManager() {
		// Given
		let params = AddPersonParameters.createParameters()
		let expectedValue = Person.createPerson()
		let addPersonCallback = Result<Person, CoreError>.success(expectedValue)
		coreDataGatewaySpy.addPersonResultToBeReturned = addPersonCallback
		// When
		sut.add(parameters: params) { _ in }
		// Then
		XCTAssertTrue(self.taskManagerSpy.processTasksCalled, "Expected to call TaskManager")
	}

	func test_SUT_WhenAddingPerson_CallingCoreDataPersonsGateway() {
		// Given
		let taskManager = TaskManagerOnGCD()
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManager)
		let params = AddPersonParameters.createParameters()
		let addPersonCallback = Result<Person, CoreError>.success(Person.createPerson())
		coreDataGatewaySpy.addPersonResultToBeReturned = addPersonCallback
		let savedPerson = expectation(description: "Expecting to save Person")
		// When
		sut.add(parameters: params) { _ in
			// Then
			XCTAssertTrue(self.coreDataGatewaySpy.addPersonCalled, "Epected to call saving person to CoreData with specified managed object context in background")
			savedPerson.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenEditingPersons_CallingTaskManagerWithExpectedResult() {
		// Given
		let expectedPerson = Person.createPerson()
		let params = AddPersonParameters.createParameters()
		let editPersonCallback = Result<Person, CoreError>.success(expectedPerson)
		coreDataGatewaySpy.editPersonResultToBeReturned = editPersonCallback
		// When
		sut.edit(person: Person.createPerson(), with: params) { _ in }
		// Then
		XCTAssertTrue(self.taskManagerSpy.processTasksCalled, "Expected to call TaskManager")
	}

	func test_SUT_WhenEditingPersons_CallingCoreDataPersonsGateway() {
		// Given
		let taskManager = TaskManagerOnGCD()
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManager)
		let editPersonCallback = Result<Person, CoreError>.success(Person.createPerson())
		coreDataGatewaySpy.editPersonResultToBeReturned = editPersonCallback
		let workIsDone = expectation(description: "Expecting to finish editing")
		// When
		sut.edit(person: Person.createPerson(), with: AddPersonParameters.createParameters(), completionHandler: { _ in
			// Then
			XCTAssertTrue(self.coreDataGatewaySpy.editPersonCalled, "Epected to call Edit Person from CoreData")
			workIsDone.fulfill()
		})
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenEditingClearsStoredPics_EnqueuesDeleteForEachClearedSlot() {
		// Given a person with both pics stored, edited to clear both slots.
		let person = Person.createPerson()
		let params = AddPersonParameters(name: "John", dayOfBirth: Date(), timeOfBirth: Date(),
										 appImage: nil, widgetImage: nil, isOnWidget: false)
		coreDataGatewaySpy.editPersonResultToBeReturned = .success(person)
		// When
		sut.edit(person: person, with: params) { _ in }
		// Then
		XCTAssertEqual(taskManagerSpy.processedTasks.count, 2, "Expected a delete task for each cleared slot")
	}

	func test_SUT_WhenEditingPersonWithoutStoredPics_EnqueuesNoTasks() {
		// Given a person with no stored pics, edited with no images.
		let person = Person(id: UUID(), name: "name", birthday: Date(), appPicId: nil, widgetPicId: nil, isOnWidget: false, createdDate: Date())
		let params = AddPersonParameters(name: "John", dayOfBirth: Date(), timeOfBirth: Date(),
										 appImage: nil, widgetImage: nil, isOnWidget: false)
		coreDataGatewaySpy.editPersonResultToBeReturned = .success(person)
		// When
		sut.edit(person: person, with: params) { _ in }
		// Then
		XCTAssertEqual(taskManagerSpy.processedTasks.count, 0, "Expected no tasks when nothing was stored or picked")
	}

	func test_SUT_WhenEditingReplacesAppPic_EnqueuesSaveAndDelete() {
		// Given a person whose app pic is replaced by a freshly picked image,
		// while the widget pic is left untouched (same id, not re-picked).
		let widgetId = UUID()
		let person = Person(id: UUID(), name: "name", birthday: Date(), appPicId: UUID(), widgetPicId: widgetId, isOnWidget: false, createdDate: Date())
		let params = AddPersonParameters(name: "John", dayOfBirth: Date(), timeOfBirth: Date(),
										 appImage: PersonImage(id: UUID(), uiImage: UIImage()),
										 widgetImage: PersonImage(id: widgetId, uiImage: nil), isOnWidget: false)
		coreDataGatewaySpy.editPersonResultToBeReturned = .success(person)
		// When
		sut.edit(person: person, with: params) { _ in }
		// Then
		XCTAssertEqual(taskManagerSpy.processedTasks.count, 2, "Expected a save for the new app pic and a delete for the replaced one")
	}

	func test_SUT_WhenEditingReplacesWidgetPic_EnqueuesSaveAndDelete() {
		// Given a person whose widget pic is replaced by a freshly picked image,
		// while the app pic is left untouched (same id, not re-picked).
		let appId = UUID()
		let person = Person(id: UUID(), name: "name", birthday: Date(), appPicId: appId, widgetPicId: UUID(), isOnWidget: false, createdDate: Date())
		let params = AddPersonParameters(name: "John", dayOfBirth: Date(), timeOfBirth: Date(),
										 appImage: PersonImage(id: appId, uiImage: nil),
										 widgetImage: PersonImage(id: UUID(), uiImage: UIImage()), isOnWidget: false)
		coreDataGatewaySpy.editPersonResultToBeReturned = .success(person)
		// When
		sut.edit(person: person, with: params) { _ in }
		// Then
		XCTAssertEqual(taskManagerSpy.processedTasks.count, 2, "Expected a save for the new widget pic and a delete for the replaced one")
	}

	func test_SUT_WhenEditingLeavesPicsUnchanged_EnqueuesNoTasks() {
		// Given a person edited without touching either pic (same ids, not re-picked).
		let appId = UUID()
		let widgetId = UUID()
		let person = Person(id: UUID(), name: "name", birthday: Date(), appPicId: appId, widgetPicId: widgetId, isOnWidget: false, createdDate: Date())
		let params = AddPersonParameters(name: "John", dayOfBirth: Date(), timeOfBirth: Date(),
										 appImage: PersonImage(id: appId, uiImage: nil),
										 widgetImage: PersonImage(id: widgetId, uiImage: nil), isOnWidget: false)
		coreDataGatewaySpy.editPersonResultToBeReturned = .success(person)
		// When
		sut.edit(person: person, with: params) { _ in }
		// Then
		XCTAssertEqual(taskManagerSpy.processedTasks.count, 0, "Expected no tasks when both pics are unchanged")
	}

	func test_SUT_WhenRemovingPersons_CallingTaskManagerWithExpectedResult() {
		// Given
		coreDataGatewaySpy.removePersonResultToBeReturned = .success(())
		let workIsDone = expectation(description: "Expecting to Remove Person")
		// When
		sut.remove(person: Person.createPerson()) { result in
			// Then
			switch result {
			case .success: ()
			case .failure(let error):
				XCTFail("Expected to Remove Person but got error = \(error.localizedDescription)")
			}
			workIsDone.fulfill()
		}
		XCTAssertTrue(self.taskManagerSpy.processTasksCalled, "Expected to call TaskManager")
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenRemovingPersons_CallingCoreDataPersonsGateway() {
		// Given
		let taskManager = TaskManagerOnGCD()
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManager)
		coreDataGatewaySpy.removePersonResultToBeReturned = .success(())
		let workIsDone = expectation(description: "Expecting to finish removing")
		// When
		sut.remove(person: Person.createPerson(), completionHandler: { _ in
			// Then
			XCTAssertTrue(self.coreDataGatewaySpy.removePersonCalled, "Epected to call Remove Person from CoreData")
			workIsDone.fulfill()
		})
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenFetchingPersons_CallingTaskManagerWithExpectedResult() {
		// Given
		let expectedValue = [Person.createPerson()]
		coreDataGatewaySpy.fetchPersonsResultToBeReturned = .success(expectedValue)
		let workIsDone = expectation(description: "Expecting to fetch Persons")
		// When
		sut.fetchPersons { result in
			// Then
			XCTAssertEqual(result, .success(expectedValue), "Expected to receive array of Persons")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_WhenFetchingPersons_CallingCoreDataPersonsGateway() {
		// Given
		let taskManager = TaskManagerOnGCD()
		sut = CachePersonsGateway(coreDataGateway: coreDataGatewaySpy, taskManager: taskManager)
		coreDataGatewaySpy.fetchPersonsResultToBeReturned = .success([])
		let workIsDone = expectation(description: "Expecting to finish fetching")
		// When
		sut.fetchPersons { _ in
			// Then
			XCTAssertTrue(self.coreDataGatewaySpy.fetchPersonsCalled, "Epected to call fetching persons from CoreData")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}
}
