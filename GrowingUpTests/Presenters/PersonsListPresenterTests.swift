//
//  PersonsListPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import XCTest

@testable import Core
@testable import GrowingUp

@MainActor
final class PersonsListPresenterTests: XCTestCase {

	var sut: PersonsListPresenterImplementation!
	let personsListSpy = PersonsListViewSpy()
	let displayPersonsUseCaseSpy = DisplayPersonsUseCaseSpy()
	let expectedPersonsToReturn = [Person.createPerson()]

	override func setUp() {
		displayPersonsUseCaseSpy.resultToBeReturned = .success(expectedPersonsToReturn)
		sut = PersonsListPresenterImplementation(view: personsListSpy, displayPersonsUseCase: displayPersonsUseCaseSpy)
	}

	func test_SUT_LoadingPersonsOnInit() async {
		await waitUntil { self.personsListSpy.didCallUpdateListOfScreens }
		// Then
		XCTAssertTrue(displayPersonsUseCaseSpy.displayPersonsCalled, "Expected to call loadiing of Persons")
		XCTAssertTrue(
			personsListSpy.didCallUpdateListOfScreens, "Expected to call updateListOfScreens after loaded Persons")
		XCTAssertEqual(
			sut.numberOfPages(), expectedPersonsToReturn.count + 1,
			"Expected to return number of pages according to returned Persons array")
	}

	func test_SUT_ReturningPersonOverviewScreenForPersonAtCorrectIndex() async {
		await waitUntil { self.displayPersonsUseCaseSpy.displayPersonsCalled }
		// Given
		let index = 0
		// When
		let screen = sut.pageViewControllerScreen(atIndex: index)
		// Then
		XCTAssertTrue(screen is PersonOverviewView, "Expected to return PersonOverview Screen")
	}

	func test_SUT_ReturningNilForIncorrectPersonIndex() async {
		await waitUntil { self.displayPersonsUseCaseSpy.displayPersonsCalled }
		// When
		let screenAt3 = sut.pageViewControllerScreen(atIndex: 2)
		let screenAtMinus1 = sut.pageViewControllerScreen(atIndex: -1)
		// Then
		XCTAssertNil(screenAt3, "Expected to return nil Screen for incorrect index")
		XCTAssertNil(screenAtMinus1, "Expected to return nil Screen for incorrect index")
	}

	func test_SUT_ReturningEmptyPersonScreenForLastPageIndex() async {
		await waitUntil { self.displayPersonsUseCaseSpy.displayPersonsCalled }
		// Given
		let lastIndex = sut.numberOfPages() - 1
		// When
		let screen = sut.pageViewControllerScreen(atIndex: lastIndex)
		// Then
		XCTAssertTrue(screen is EmptyPersonView, "Expected to return EmptyPerson Screen")
	}

	private func waitUntil(_ condition: @escaping () -> Bool) async {
		for _ in 0..<1_000 {
			if condition() { return }
			await Task.yield()
		}
		XCTFail("Timed out waiting for async presenter work")
	}
}
