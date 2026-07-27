//
//  CoreDataPersonsGatewayTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest

@testable import Core
@testable import GrowingUp

class CoreDataPersonsGatewayTests: XCTestCase {

  // https://www.martinfowler.com/bliki/TestDouble.html
  var inMemoryCoreDataStack = InMemoryCoreDataStack()
  var managedObjectContextSpy = NSManagedObjectContextSpy()
  var inMemoryCoreDataGateway: CoreDataPersonsGateway {
    return CoreDataPersonsGateway(coreDataStack: inMemoryCoreDataStack)
  }

  func test_SUT_AddPersonWithParameters_Succeed() {
    // Given
    let addPersonParameters = AddPersonParameters.createParameters()
    let addPersonCompletionHandlerExpectation = expectation(description: "Add person completion handler expectation")
    // When
    inMemoryCoreDataGateway.add(parameters: addPersonParameters) { (result) in
      // Then
      guard let person = try? result.get() else {
        return XCTFail("Should've saved the person with success")
      }
      assert(person: person, builtFromParameters: addPersonParameters)
      addPersonCompletionHandlerExpectation.fulfill()
    }
    // Exit
    waitForExpectations(timeout: 5, handler: nil)
  }

  func test_SUT_EditPerson_ShouldSucceedWithCorrectParameters() {
    // Given
    let cdPerson = inMemoryCoreDataStack.fakeEntity(withType: CoreDataPerson.self)
    cdPerson.id = UUID().uuidString
    cdPerson.createdDate = Date()
    cdPerson.birthdate = Date()
    inMemoryCoreDataStack.saveContext()
    var editParams = AddPersonParameters.createParameters()
    editParams.name = "John Snow"
    editParams.isOnWidget = true
    editParams.dayOfBirth = Date().addingTimeInterval(-60 * 60 * 24 * 365 * 10)
    editParams.timeOfBirth = Date().addingTimeInterval(-60)
    let expect = expectation(description: "Edit")
    // When
    inMemoryCoreDataGateway.edit(person: cdPerson.person, with: editParams) { result in
      // Then
      switch result {
      case .success(let person):
        assert(person: person, builtFromParameters: editParams)
      case .failure(let error):
        XCTFail("Expected to successfully edit person, but received error = \(error.localizedDescription)")
      }
      expect.fulfill()
    }
    // Exit
    waitForExpectations(timeout: 1)
  }

  func test_SUT_RemovePerson_ShouldSucceed() {
    // Given
    let cdPerson = inMemoryCoreDataStack.fakeEntity(withType: CoreDataPerson.self)
    cdPerson.id = UUID().uuidString
    cdPerson.createdDate = Date()
    cdPerson.birthdate = Date()
    inMemoryCoreDataStack.saveContext()
    let expect = expectation(description: "Remove")
    // When
    inMemoryCoreDataGateway.remove(person: cdPerson.person) { result in
      // Then
      assertOk(result, "Expected to successfully edit person, but received error")
      expect.fulfill()
    }
    // Exit
    waitForExpectations(timeout: 1)
  }

  func test_SUT_FetchPersons_ShouldSucceed() {
    // Given
    let workIsDone = expectation(description: "Fetch persons completion handler expectation")
    // When
    inMemoryCoreDataGateway.fetchPersons { result in
      // Then
      switch result {
      case .failure: XCTFail("Should've fetched persons with success")
      default: ()
      }
      workIsDone.fulfill()
    }
    // Exit
    waitForExpectations(timeout: 0.1, handler: nil)
  }

}

private func assert(
  person: Person, builtFromParameters parameters: AddPersonParameters, file: StaticString = #file, line: UInt = #line
) {
  XCTAssertEqual(person.name, parameters.name, "name mismatch", file: file, line: line)
  XCTAssertEqual(
    person.birthday.timeIntervalSince1970, parameters.combinedDate().timeIntervalSince1970, "birthday mismatch",
    file: file, line: line)
  XCTAssertEqual(person.appPicId, parameters.appImage?.id, "app pic mismatch", file: file, line: line)
  XCTAssertEqual(person.widgetPicId, parameters.widgetImage?.id, "widget pic mismatch", file: file, line: line)
  XCTAssertEqual(person.isOnWidget, parameters.isOnWidget, "fav state mismatch", file: file, line: line)
}
