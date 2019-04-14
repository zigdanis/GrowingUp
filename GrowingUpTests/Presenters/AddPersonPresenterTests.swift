//
//  AddPersonPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp

final class AddPersonPresenterTests: XCTestCase {

    // https://www.martinfowler.com/bliki/TestDouble.html
    let addPersonViewSpy = AddPersonViewSpy()
    let addPersonUseCaseSpy = AddPersonUseCaseSpy()
    let addPersonViewRouterSpy = AddPersonViewRouterSpy()
    let addPersonPresenterDelegateSpy = AddPersonPresenterDelegateSpy()
	let imagesCellStub = ImagesCellPresenterStub()
	let nameCellStub = TextFieldCellPresenterStub()
	let dateCellsStub = DateCellPresenterStub()
	let dateComponentsStub = SwitchCellPresenterStub()

    var sut: AddPersonPresenterImplementation!

    // MARK: - Set up

    override func setUp() {
        super.setUp()
		sut = AddPersonPresenterImplementation(view: addPersonViewSpy,
											   addPersonUseCase: addPersonUseCaseSpy,
											   router: addPersonViewRouterSpy,
											   delegate: addPersonPresenterDelegateSpy,
											   imagesCellPresenter: imagesCellStub,
											   nameCellPresenter: nameCellStub,
											   dateCellsPresenter: dateCellsStub,
											   dateComponentsCellsPresenter: dateComponentsStub)
    }

    func test_SUT_CancelPressed_CalledCancelOnDelegate() {
        // When
        sut.cancelButtonPressed()
        // Then
        XCTAssertTrue(addPersonPresenterDelegateSpy.didCalledCancel, "Should have been called cancel on delegate")
    }

    func test_SUT_AddButtonPressed_AddAndCancelButtonsDisabledBeforeCompletionHandler() {
        // Given
		setupSUT_WithAddPersonData()
        addPersonUseCaseSpy.callCompletionHandlerImmediate = false
        // When
        sut.addButtonPressed()
        // Then
        XCTAssertFalse(addPersonViewSpy.addButtonEnabledState ?? true, "Add button should've been set to disabled")
        XCTAssertFalse(addPersonViewSpy.cancelButtonEnabledState ?? true, "Cancel button should've been set to disabled")
    }

    func test_SUT_AddButtonPressed_AddAndCancelButtonsEnabledAfterCompletionHandlerCalled() {
        // Given
		setupSUT_WithAddPersonData()
        addPersonUseCaseSpy.resultToBeReturned = .success(Person.createPerson())
        // When
        sut.addButtonPressed()
        // Then
        XCTAssertTrue(addPersonViewSpy.addButtonEnabledState ?? false, "Add button should've been set to enabled")
        XCTAssertTrue(addPersonViewSpy.cancelButtonEnabledState ?? false, "Cancel button should've been set to enabled")
    }

    func test_SUT_AddButtonPressed_ShouldSavePerson() {
        // Given
		let parameters = setupSUT_WithAddPersonData()
        addPersonUseCaseSpy.resultToBeReturned = .success(Person.createPerson())
        // When
        sut.addButtonPressed()
        // Then
        XCTAssertEqual(addPersonUseCaseSpy.personToAddParameters, parameters, "Should have been called addPerson for AddPersonUseCase")
    }

    func test_SUT_AddButtonPressed_CallingAddPersonDelegateMethod() {
        // Given
		setupSUT_WithAddPersonData()
        let expectedPersonToAdd = Person.createPerson()
        addPersonUseCaseSpy.resultToBeReturned = .success(expectedPersonToAdd)
        // When
        sut.addButtonPressed()
        // Then
        XCTAssertEqual(addPersonPresenterDelegateSpy.addedPerson, expectedPersonToAdd, "Should have been add expected person")
        XCTAssertTrue(addPersonPresenterDelegateSpy.didCalledAddPerson, "Should have been call addPerson on Delegate")

    }

    func test_SUT_AddButtonPressedWithError_ShouldDisplayErrorOnView() {
        // Given
		setupSUT_WithAddPersonData()
        let expectedErrorTitle = "Error"
        let expectedErrorMessage = "Some error message"
        addPersonUseCaseSpy.resultToBeReturned = .failure(CoreError(title: expectedErrorTitle, message: expectedErrorMessage))
        // When
        sut.addButtonPressed()
        // Then
        XCTAssertEqual(expectedErrorTitle, addPersonViewSpy.displayAddPersonErrorTitle, "Error title doesn't match")
        XCTAssertEqual(expectedErrorMessage, addPersonViewSpy.displayAddPersonErrorMessage, "Error message doesn't match")
    }

	func test_SUT_AddButtonPressedWithoutName_ShouldShowError() {
		// When
		sut.addButtonPressed()
		// Then
		XCTAssertEqual(addPersonViewSpy.displayAddPersonErrorTitle, CoreError.noNameValue.title, "Error message doesn't match")
		XCTAssertEqual(addPersonViewSpy.displayAddPersonErrorMessage, CoreError.noNameValue.message, "Error message doesn't match")
	}

	func test_SUT_AddButtonPressedWithoutBirthDay_ShouldShowError() {
		// Given
		nameCellStub.valueFor(row: APC.nameFieldRow, didChangeTo: "John")
		// When
		sut.addButtonPressed()
		// Then
		XCTAssertEqual(addPersonViewSpy.displayAddPersonErrorTitle, CoreError.noDayValue.title, "Error message doesn't match")
		XCTAssertEqual(addPersonViewSpy.displayAddPersonErrorMessage, CoreError.noDayValue.message, "Error message doesn't match")
	}

	func test_SUT_AddButtonPressedWithoutBirthTime_ShouldShowError() {
		// Given
		nameCellStub.valueFor(row: APC.nameFieldRow, didChangeTo: "John")
		dateCellsStub.valueFor(row: APC.dayPickerRow, didChangeTo: Date())
		// When
		sut.addButtonPressed()
		// Then
		XCTAssertEqual(addPersonViewSpy.displayAddPersonErrorTitle, CoreError.noTimeValue.title, "Error message doesn't match")
		XCTAssertEqual(addPersonViewSpy.displayAddPersonErrorMessage, CoreError.noTimeValue.message, "Error message doesn't match")
	}

	func test_SUT_WhenSettingDateForRow_PassingItToDateCellsPresenter() {
		// Given
		let expectedDay = Date()
		let expectedTime = Date().addingTimeInterval(1)
		// When
		sut.dateFor(row: 1, didUpdateTo: expectedDay)
		sut.dateFor(row: 2, didUpdateTo: expectedTime)
		// Then
		XCTAssertEqual(dateCellsStub.valueFor(row: 1), expectedDay, "Expected value doesn't match")
		XCTAssertEqual(dateCellsStub.valueFor(row: 2), expectedTime, "Expected value doesn't match")
	}

	func test_SUT_WhenCalledWithNewPersonPic_ReplaceItOnImagesCellPresenter() {
		// Given
		let expectedAppPic = UIImage()
		let personAppPic = PersonImage(uiImage: expectedAppPic)
		let expectedWidgetPic = UIImage()
		let personWidgetPic = PersonImage(uiImage: expectedWidgetPic)
		// When
		sut.appImagePicked(image: personAppPic)
		sut.widgetImagePicked(image: personWidgetPic)
		// Then
		let appPic = imagesCellStub.valueFor(row: APC.imagePickerRow)?.appPic
		let widgetPic = imagesCellStub.valueFor(row: APC.imagePickerRow)?.widgetPic
		XCTAssertEqual(appPic, personAppPic, "Value for the person App pic doesn't match to expected")
		XCTAssertEqual(widgetPic, personWidgetPic, "Value for the person Widget pic doesn't match to expected")
	}

	func test_SUT_WhenConfiguringCells_ShouldCallTheirPresenters() {
		// Given
		let imgSpy = ImagesCellViewSpy()
		let tfSpy = TextFieldCellViewSpy()
		let dateSpy = DateCellViewSpy()
		let switchSpy = SwitchCellViewSpy()
		// When
		sut.configure(cell: imgSpy, forRow: 0)
		sut.configure(cell: tfSpy, forRow: 0)
		sut.configure(cell: dateSpy, forRow: 0)
		sut.configure(cell: switchSpy, forRow: 0)
		// Then
		XCTAssertTrue(imagesCellStub.didCallConfigure, "Expected to call child presenter")
		XCTAssertTrue(nameCellStub.didCallConfigure, "Expected to call child presenter")
		XCTAssertTrue(dateCellsStub.didCallConfigure, "Expected to call child presenter")
		XCTAssertTrue(imagesCellStub.didCallConfigure, "Expected to call child presenter")
	}

	func test_WhenTextFieldObserverUpdateText_SUT_CallingViewToUpdateTitle() {
		// Given
		let expectedTitle = "Hello"
		let tfSpy = TextFieldCellViewSpy()
		// When
		sut.textDidChange(forView: tfSpy, text: expectedTitle)
		// Then
		XCTAssertEqual(addPersonViewSpy.displayedScreenTitle, expectedTitle, "Expected To Display New Title")
	}

	// MARK: - Helpers

	@discardableResult
	private func setupSUT_WithAddPersonData() -> AddPersonParameters {
		nameCellStub.valueFor(row: APC.nameFieldRow, didChangeTo: "John")
		let bDate = Date()
		let tDate = Date().addingTimeInterval(1)
		dateCellsStub.valueFor(row: APC.dayPickerRow, didChangeTo: bDate)
		dateCellsStub.valueFor(row: APC.timePickerRow, didChangeTo: tDate)
		for row in APC.dateComponentsRows {
			dateComponentsStub.valueFor(row: row, didChangeTo: true)
		}
		let appPic = PersonImage(id: UUID(), uiImage: UIImage())
		let widgetPic = PersonImage(id: UUID(), uiImage: UIImage())
		let pics = PersonImages(appPic: appPic, widgetPic: widgetPic)
		imagesCellStub.valueFor(row: APC.imagePickerRow, didChangeTo: pics)
		return AddPersonParameters(name: "John", dayOfBirth: bDate, timeOfBirth: tDate, dateComponenets: AddPersonDateComponents(), appImage: appPic, widgetImage: widgetPic)
	}
}
