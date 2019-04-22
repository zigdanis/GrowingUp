//
//  AddPersonPresenterTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp
@testable import Core

final class EditPersonPresenterTests: XCTestCase {

    // https://www.martinfowler.com/bliki/TestDouble.html
    let editPersonViewSpy = EditPersonViewSpy()
    let editPersonUseCaseSpy = EditPersonUseCaseSpy()
    let addPersonViewRouterSpy = EditPersonViewRouterSpy()
    let addPersonPresenterDelegateSpy = EditPersonPresenterDelegateSpy()
	let imagesCellStub = ImagesCellPresenterStub()
	let nameCellStub = TextFieldCellPresenterStub()
	let dateCellsStub = DateCellPresenterStub()
	let dateComponentsStub = SwitchCellPresenterStub()

    var sut: EditPersonPresenterImplementation!

    // MARK: - Set up

    override func setUp() {
        super.setUp()
		let person = Person.createPerson()
		sut = EditPersonPresenterImplementation(person: person,
												view: editPersonViewSpy,
												editPersonUseCase: editPersonUseCaseSpy,
												router: addPersonViewRouterSpy,
												delegate: addPersonPresenterDelegateSpy,
												imagesCellPresenter: imagesCellStub,
												nameCellPresenter: nameCellStub,
												dateCellsPresenter: dateCellsStub,
												dateComponentsCellsPresenter: dateComponentsStub)
    }

    func test_SUT_ClosePressed_CalledCancelOnDelegate() {
        // When
        sut.leftBarButtonPressed()
        // Then
        XCTAssertTrue(addPersonPresenterDelegateSpy.didCalledCancel, "Should have been called cancel on delegate")
    }

    func test_SUT_SaveButtonPressed_BarButtonsDisabledBeforeCompletionHandler() {
        // Given
		setupSUT_WithAddPersonData()
        editPersonUseCaseSpy.callCompletionHandlerImmediate = false
        // When
        sut.rightBarButtonPressed()
        // Then
        XCTAssertFalse(editPersonViewSpy.barButtonsEnabledState ?? true, "Bar buttons should've been set to disabled")
    }

    func test_SUT_SaveButtonPressed_BarButtonsEnabledAfterCompletionHandlerCalled() {
        // Given
		setupSUT_WithAddPersonData()
        editPersonUseCaseSpy.resultToBeReturned = .success(Person.createPerson())
        // When
        sut.rightBarButtonPressed()
        // Then
        XCTAssertTrue(editPersonViewSpy.barButtonsEnabledState ?? false, "Bar buttons should've been set to enabled")
    }

    func test_SUT_SaveButtonPressed_ShouldStartEditingPerson() {
        // Given
		let parameters = setupSUT_WithAddPersonData()
        editPersonUseCaseSpy.resultToBeReturned = .success(Person.createPerson())
        // When
        sut.rightBarButtonPressed()
        // Then
        XCTAssertEqual(editPersonUseCaseSpy.personToEditParameters, parameters, "Should have been called addPerson for AddPersonUseCase")
    }

    func test_SUT_SaveButtonPressed_CallingEditPersonDelegateMethod() {
        // Given
		setupSUT_WithAddPersonData()
        let expectedPersonToEdit = Person.createPerson()
        editPersonUseCaseSpy.resultToBeReturned = .success(expectedPersonToEdit)
        // When
        sut.rightBarButtonPressed()
        // Then
        XCTAssertEqual(addPersonPresenterDelegateSpy.editedPerson, expectedPersonToEdit, "Should have been edit expected person")
        XCTAssertTrue(addPersonPresenterDelegateSpy.didCalledEditPerson, "Should have been call editPerson on Delegate")

    }

    func test_SUT_SaveButtonPressedWithError_ShouldDisplayErrorOnView() {
        // Given
		setupSUT_WithAddPersonData()
        let expectedErrorTitle = "Error"
        let expectedErrorMessage = "Some error message"
        editPersonUseCaseSpy.resultToBeReturned = .failure(CoreError(title: expectedErrorTitle, message: expectedErrorMessage))
        // When
        sut.rightBarButtonPressed()
        // Then
		XCTAssertEqual(expectedErrorTitle, editPersonViewSpy.displayAddPersonErrorTitle, "Error title doesn't match")
		XCTAssertEqual(expectedErrorMessage, editPersonViewSpy.displayAddPersonErrorMessage, "Error message doesn't match")
    }

	func test_SUT_SaveButtonPressedWithoutName_ShouldShowError() {
		// When
		sut.rightBarButtonPressed()
		// Then
		XCTAssertEqual(editPersonViewSpy.displayAddPersonErrorTitle, CoreError.noNameValue.title, "Error message doesn't match")
		XCTAssertEqual(editPersonViewSpy.displayAddPersonErrorMessage, CoreError.noNameValue.message, "Error message doesn't match")
	}

	func test_SUT_SaveButtonPressedWithoutBirthDay_ShouldShowError() {
		// Given
		nameCellStub.valueFor(row: EPC.nameFieldRow, didChangeTo: "John")
		// When
		sut.rightBarButtonPressed()
		// Then
		XCTAssertEqual(editPersonViewSpy.displayAddPersonErrorTitle, CoreError.noDayValue.title, "Error message doesn't match")
		XCTAssertEqual(editPersonViewSpy.displayAddPersonErrorMessage, CoreError.noDayValue.message, "Error message doesn't match")
	}

	func test_SUT_SaveButtonPressedWithoutBirthTime_ShouldShowError() {
		// Given
		nameCellStub.valueFor(row: EPC.nameFieldRow, didChangeTo: "John")
		dateCellsStub.valueFor(row: EPC.dayPickerRow, didChangeTo: Date())
		// When
		sut.rightBarButtonPressed()
		// Then
		XCTAssertEqual(editPersonViewSpy.displayAddPersonErrorTitle, CoreError.noTimeValue.title, "Error message doesn't match")
		XCTAssertEqual(editPersonViewSpy.displayAddPersonErrorMessage, CoreError.noTimeValue.message, "Error message doesn't match")
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
		let appPic = imagesCellStub.valueFor(row: EPC.imagePickerRow)?.appPic
		let widgetPic = imagesCellStub.valueFor(row: EPC.imagePickerRow)?.widgetPic
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
		XCTAssertEqual(editPersonViewSpy.displayedScreenTitle, expectedTitle, "Expected To Display New Title")
	}

	func test_SUT_OnViewDidLoad_SetsBarButtonsWithCloseAndSaveTypes() {
		// When
		sut.viewDidLoad()
		// Then
		XCTAssertTrue(editPersonViewSpy.displayedBarButtons.contains(.cancel), "Expected to display Cancel button")
		XCTAssertTrue(editPersonViewSpy.displayedBarButtons.contains(.save), "Expected to display Save button")
		XCTAssertEqual(editPersonViewSpy.displayedBarButtons.count, 2, "Expected to display only 2 type of buttons")
	}

	// MARK: - Helpers

	@discardableResult
	private func setupSUT_WithAddPersonData() -> AddPersonParameters {
		nameCellStub.valueFor(row: EPC.nameFieldRow, didChangeTo: "John")
		let bDate = Date()
		let tDate = Date().addingTimeInterval(1)
		dateCellsStub.valueFor(row: EPC.dayPickerRow, didChangeTo: bDate)
		dateCellsStub.valueFor(row: EPC.timePickerRow, didChangeTo: tDate)
		for row in EPC.dateComponentsRows {
			dateComponentsStub.valueFor(row: row, didChangeTo: true)
		}
		let appPic = PersonImage(id: UUID(), uiImage: UIImage())
		let widgetPic = PersonImage(id: UUID(), uiImage: UIImage())
		let pics = PersonImages(appPic: appPic, widgetPic: widgetPic)
		imagesCellStub.valueFor(row: EPC.imagePickerRow, didChangeTo: pics)
		return AddPersonParameters(name: "John", dayOfBirth: bDate, timeOfBirth: tDate, dateComponents: AddPersonDateComponents(), appImage: appPic, widgetImage: widgetPic)
	}
}
