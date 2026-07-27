//
//  EditPersonPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import Core

protocol EditPersonPresenter: TextFieldObserver, ToggleCellDelegate, DateCellDelegate {
    var router: EditPersonViewRouter { get }
	func viewDidLoad()
    func rightBarButtonPressed()
	func leftBarButtonPressed()
	func removePersonPressed()
	func configure(cell: ImagesCellView, forRow row: Int)
    func configure(cell: TextFieldCellView, forRow row: Int)
    func configure(cell: DateCellView, forRow row: Int)
	func configure(cell: ToggleCellView, forRow row: Int)
	func dateFor(row: Int, didUpdateTo date: Date)
	func onWidgetStateFor(row: Int, didUpdateTo state: Bool)
	func appImagePicked(image: PersonImage)
	func widgetImagePicked(image: PersonImage)
	func removeAppImage()
	func removeWidgetImage()
	func shouldShowRemoveButton() -> Bool
}

protocol EditPersonPresenterDelegate: AnyObject {
    func editPersonPresenter(_ presenter: EditPersonPresenter, didAdd person: Person)
	func editPersonPresenter(_ presenter: EditPersonPresenter, didEdit person: Person)
	func editPersonPresenter(_ presenter: EditPersonPresenter, didRemove person: Person)
    func editPersonPresenterCancel(presenter: EditPersonPresenter)
}

final class EditPersonPresenterImplementation: EditPersonPresenter {

	private let person: Person
    private weak var view: EditPersonView?
    private let editPersonUseCase: EditPersonUseCase
	private let removePersonUseCase: RemovePersonUseCase
    private weak var delegate: EditPersonPresenterDelegate?
    private(set) var router: EditPersonViewRouter
	private let imagesCellPresenter: ImagesCellPresenter
	private let nameCellPresenter: TextFieldCellPresenter
	private let dateCellsPresenter: DateCellPresenter
	private let toggleCellPresenter: ToggleCellPresenter

	init(person: Person,
		 view: EditPersonView,
		 editPersonUseCase: EditPersonUseCase,
		 removePersonUseCase: RemovePersonUseCase,
		 router: EditPersonViewRouter,
		 delegate: EditPersonPresenterDelegate?,
		 imagesCellPresenter: ImagesCellPresenter,
		 nameCellPresenter: TextFieldCellPresenter,
		 dateCellsPresenter: DateCellPresenter,
		 toggleCellPresenter: ToggleCellPresenter) {
		self.person = person
		self.view = view
		self.editPersonUseCase = editPersonUseCase
		self.removePersonUseCase = removePersonUseCase
		self.router = router
		self.delegate = delegate
		self.imagesCellPresenter = imagesCellPresenter
		self.nameCellPresenter = nameCellPresenter
		self.dateCellsPresenter = dateCellsPresenter
		self.toggleCellPresenter = toggleCellPresenter
	}

    // MARK: - EditPersonPresenter

	func viewDidLoad() {
		view?.displayBarButton(with: .cancel)
		view?.displayBarButton(with: .save)
		view?.displayScreenTitle(title: person.name)

		nameCellPresenter.valueFor(row: EPC.nameFieldRow, didChangeTo: person.name)
		dateCellsPresenter.valueFor(row: EPC.dayPickerRow, didChangeTo: person.dayOfBirth)
		dateCellsPresenter.valueFor(row: EPC.timePickerRow, didChangeTo: person.timeOfBirth)
		toggleCellPresenter.valueFor(row: EPC.addToWidgetRow, didChangeTo: person.isOnWidget)

		loadAndShowPersonPics()
	}

	private func loadAndShowPersonPics() {
		let appPic = PersonImage(id: person.appPicId)
		let widgetPic = PersonImage(id: person.widgetPicId)
		let personImages = PersonImages(appPic: appPic, widgetPic: widgetPic)
		imagesCellPresenter.valueFor(row: EPC.imagePickerRow, didChangeTo: personImages)
	}

	func rightBarButtonPressed() {
		var params: AddPersonParameters?
		do {
			params = try collectAddPersonParameters()
		} catch {
			handleEditPersonError(error)
		}

		guard let parameters = params else { return }
        updateNavigationItemsState(isEnabled: false)
		editPersonUseCase.edit(person: person, with: parameters) { result in
			self.updateNavigationItemsState(isEnabled: true)
			switch result {
			case let .success(person):
				self.handlePersonEdited(person)
			case let .failure(error):
				self.handleEditPersonError(error)
			}
		}
    }

	func leftBarButtonPressed() {
        delegate?.editPersonPresenterCancel(presenter: self)
    }

	func removePersonPressed() {
		updateNavigationItemsState(isEnabled: false)
		removePersonUseCase.remove(person: person) { result in
			self.updateNavigationItemsState(isEnabled: true)
			switch result {
			case .success:
				self.handlePersonRemoved()
			case .failure(let error):
				self.handleEditPersonError(error)
			}
		}
	}

	func configure(cell: ImagesCellView, forRow row: Int) {
		guard let view = view else { return }
		imagesCellPresenter.configure(cell: cell, forRow: row, with: view)
	}

	func configure(cell: TextFieldCellView, forRow row: Int) {
		nameCellPresenter.configure(cell: cell, forRow: row)
    }

    func configure(cell: DateCellView, forRow row: Int) {
       	dateCellsPresenter.configure(cell: cell, forRow: row)
    }

	func configure(cell: ToggleCellView, forRow row: Int) {
		toggleCellPresenter.configure(cell: cell, forRow: row)
	}

	func dateFor(row: Int, didUpdateTo date: Date) {
		dateCellsPresenter.valueFor(row: row, didChangeTo: date)
	}

	func onWidgetStateFor(row: Int, didUpdateTo state: Bool) {
		toggleCellPresenter.valueFor(row: row, didChangeTo: state)
	}

	func appImagePicked(image: PersonImage) {
		var personPics = imagesCellPresenter.valueFor(row: EPC.imagePickerRow) ?? PersonImages.emptyImages()
		personPics.appPic = image
		imagesCellPresenter.valueFor(row: EPC.imagePickerRow, didChangeTo: personPics)
	}

	func widgetImagePicked(image: PersonImage) {
		var personPics = imagesCellPresenter.valueFor(row: EPC.imagePickerRow) ?? PersonImages.emptyImages()
		personPics.widgetPic = image
		imagesCellPresenter.valueFor(row: EPC.imagePickerRow, didChangeTo: personPics)
	}

	func removeAppImage() {
		var personPics = imagesCellPresenter.valueFor(row: EPC.imagePickerRow) ?? PersonImages.emptyImages()
		personPics.appPic = nil
		imagesCellPresenter.valueFor(row: EPC.imagePickerRow, didChangeTo: personPics)
	}

	func removeWidgetImage() {
		var personPics = imagesCellPresenter.valueFor(row: EPC.imagePickerRow) ?? PersonImages.emptyImages()
		personPics.widgetPic = nil
		imagesCellPresenter.valueFor(row: EPC.imagePickerRow, didChangeTo: personPics)
	}

	func shouldShowRemoveButton() -> Bool {
		return true
	}

    // MARK: - Private

    private func handlePersonEdited(_ person: Person) {
		delegate?.editPersonPresenter(self, didEdit: person)
    }

    private func handleEditPersonError(_ error: Error) {
		let coreError = error as? CoreError
		let title = coreError?.title ?? String(localized: "Error")
		let message = coreError?.message ?? error.localizedDescription
		Logging.logError(coreError ?? CoreError(title: title, message: message))
		view?.displayEditPersonError(title: title, message: message)
    }

	private func handlePersonRemoved() {
		delegate?.editPersonPresenter(self, didRemove: person)
	}

    private func updateNavigationItemsState(isEnabled enabled: Bool) {
		view?.updateBarButtonsState(isEnabled: enabled)
    }

	private func collectAddPersonParameters() throws -> AddPersonParameters {
		guard let name = nameCellPresenter.valueFor(row: EPC.nameFieldRow), !name.isEmpty else {
			throw CoreError.noNameValue
		}
		guard let dayOfBirth = dateCellsPresenter.valueFor(row: EPC.dayPickerRow) else {
			throw CoreError.noDayValue
		}
		guard let timeOfBirth = dateCellsPresenter.valueFor(row: EPC.timePickerRow) else {
			throw CoreError.noTimeValue
		}
		let personPics = imagesCellPresenter.valueFor(row: EPC.imagePickerRow)
		let appPic = personPics?.appPic
		let widgetPic = personPics?.widgetPic
		let isOnWidget = toggleCellPresenter.valueFor(row: EPC.addToWidgetRow)
		return AddPersonParameters(name: name,
								   dayOfBirth: dayOfBirth,
								   timeOfBirth: timeOfBirth,
								   appImage: appPic,
								   widgetImage: widgetPic,
								   isOnWidget: isOnWidget)
	}
}

extension EditPersonPresenterImplementation: TextFieldObserver {

	func textDidChange(forView: TextFieldCellView, text: String) {
		view?.displayScreenTitle(title: text)
	}
}

extension EditPersonPresenterImplementation: ToggleCellDelegate {

	func toggle(toggle: ToggleCellView, didChangeStateForRow row: Int, to state: Bool) {
		toggleCellPresenter.valueFor(row: row, didChangeTo: state)
	}
}

extension EditPersonPresenterImplementation: DateCellDelegate {

	func dateCell(_ cell: DateCellView, didChangeBirthdayTo date: Date) {
		dateCellsPresenter.valueFor(row: EPC.dayPickerRow, didChangeTo: date)
		dateCellsPresenter.valueFor(row: EPC.timePickerRow, didChangeTo: date)
	}
}
