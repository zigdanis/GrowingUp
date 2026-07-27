//
//  PersonsListPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest

@testable import Core
@testable import GrowingUp

class PersonsListPresenterTests: XCTestCase {

	var sut: PersonsListPresenterImplementation!
	let personsListSpy = PersonsListViewSpy()
	let displayPersonsUseCaseSpy = DisplayPersonsUseCaseSpy()
	let expectedPersonsToReturn = [Person.createPerson()]

	override func setUp() {
		displayPersonsUseCaseSpy.resultToBeReturned = .success(expectedPersonsToReturn)
		sut = PersonsListPresenterImplementation(view: personsListSpy, displayPersonsUseCase: displayPersonsUseCaseSpy)
	}

	func test_SUT_LoadingPersonsOnInit() {
		// Then
		XCTAssertTrue(displayPersonsUseCaseSpy.displayPersonsCalled, "Expected to call loadiing of Persons")
		XCTAssertTrue(
			personsListSpy.didCallUpdateListOfScreens, "Expected to call updateListOfScreens after loaded Persons")
		XCTAssertEqual(
			sut.numberOfPages(), expectedPersonsToReturn.count + 1,
			"Expected to return number of pages according to returned Persons array")
	}

	func test_SUT_ReturningPersonOverviewScreenForPersonAtCorrectIndex() {
		// Given
		let index = 0
		// When
		let screen = sut.pageViewControllerScreen(atIndex: index)
		// Then
		XCTAssertTrue(screen is PersonOverviewView, "Expected to return PersonOverview Screen")
	}

	func test_SUT_ReturningNilForIncorrectPersonIndex() {
		// When
		let screenAt3 = sut.pageViewControllerScreen(atIndex: 2)
		let screenAtMinus1 = sut.pageViewControllerScreen(atIndex: -1)
		// Then
		XCTAssertNil(screenAt3, "Expected to return nil Screen for incorrect index")
		XCTAssertNil(screenAtMinus1, "Expected to return nil Screen for incorrect index")
	}

	func test_SUT_ReturningEmptyPersonScreenForLastPageIndex() {
		// Given
		let lastIndex = sut.numberOfPages() - 1
		// When
		let screen = sut.pageViewControllerScreen(atIndex: lastIndex)
		// Then
		XCTAssertTrue(screen is EmptyPersonView, "Expected to return EmptyPerson Screen")
	}
}
