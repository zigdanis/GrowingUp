//
//  AddPersonPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 16/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import Core

final class AddPersonPresenter: EditPersonPresenter {

	private weak var view: EditPersonView?
	private let addPersonUseCase: AddPersonUseCase
	private weak var delegate: EditPersonPresenterDelegate?
	private(set) var router: EditPersonViewRouter
	private let imagesCellPresenter: ImagesCellPresenter
	private let nameCellPresenter: TextFieldCellPresenter
	private let dateCellsPresenter: DateCellPresenter
	private let dateComponentsCellsPresenter: SwitchCellPresenter

	init(view: EditPersonView,
		 addPersonUseCase: AddPersonUseCase,
		 router: EditPersonViewRouter,
		 delegate: EditPersonPresenterDelegate?,
		 imagesCellPresenter: ImagesCellPresenter,
		 nameCellPresenter: TextFieldCellPresenter,
		 dateCellsPresenter: DateCellPresenter,
		 dateComponentsCellsPresenter: SwitchCellPresenter) {
		self.view = view
		self.addPersonUseCase = addPersonUseCase
		self.router = router
		self.delegate = delegate
		self.imagesCellPresenter = imagesCellPresenter
		self.nameCellPresenter = nameCellPresenter
		self.dateCellsPresenter = dateCellsPresenter
		self.dateComponentsCellsPresenter = dateComponentsCellsPresenter
	}

	// MARK: - EditPersonPresenter

	func viewDidLoad() {
		view?.displayBarButton(with: .cancel)
		view?.displayBarButton(with: .done)
	}

	func rightBarButtonPressed() {
		var params: AddPersonParameters?
		do {
			params = try collectAddPersonParameters()
		} catch {
			handleAddPersonError(error)
		}

		guard let parameters = params else { return }
		updateNavigationItemsState(isEnabled: false)
		addPersonUseCase.add(parameters: parameters) { result in
			self.updateNavigationItemsState(isEnabled: true)
			switch result {
			case let .success(person):
				self.handlePersonAdded(person)
			case let .failure(error):
				self.handleAddPersonError(error)
			}
		}
	}

	func leftBarButtonPressed() {
		delegate?.editPersonPresenterCancel(presenter: self)
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

	func configure(cell: SwitchCellView, forRow row: Int) {
		dateComponentsCellsPresenter.configure(cell: cell, forRow: row)
	}

	func dateFor(row: Int, didUpdateTo date: Date) {
		dateCellsPresenter.valueFor(row: row, didChangeTo: date)
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

	func dateForDayPicker() -> Date {
		return dateCellsPresenter.valueFor(row: EPC.dayPickerRow) ?? Date()
	}

	func dateForTimePicker() -> Date {
		return dateCellsPresenter.valueFor(row: EPC.timePickerRow) ?? Date()
	}

	// MARK: - Private

	private func handlePersonAdded(_ person: Person) {
		delegate?.editPersonPresenter(self, didAdd: person)
	}

	private func handleAddPersonError(_ error: Error) {
		let coreError = error as? CoreError
		let title = coreError?.title ?? R.string.localizable.error()
		let message = coreError?.message ?? error.localizedDescription
		view?.displayEditPersonError(title: title, message: message)
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
		let components = dateComponentsCellsPresenter.updatedComponents()
		let personPics = imagesCellPresenter.valueFor(row: EPC.imagePickerRow)
		let appPic = personPics?.appPic
		let widgetPic = personPics?.widgetPic
		return AddPersonParameters(name: name,
								   dayOfBirth: dayOfBirth,
								   timeOfBirth: timeOfBirth,
								   dateComponents: components,
								   appImage: appPic,
								   widgetImage: widgetPic)
	}
}

extension AddPersonPresenter: TextFieldObserver {

	func textDidChange(forView: TextFieldCellView, text: String) {
		view?.displayScreenTitle(title: text)
	}
}
