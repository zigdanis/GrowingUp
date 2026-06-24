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
	private let fetchWidgetPersonsUseCase: FetchPersonsUseCase
	private weak var delegate: EditPersonPresenterDelegate?
	private(set) var router: EditPersonViewRouter
	private let imagesCellPresenter: ImagesCellPresenter
	private let nameCellPresenter: TextFieldCellPresenter
	private let dateCellsPresenter: DateCellPresenter
	private let toggleCellPresenter: ToggleCellPresenter

	init(view: EditPersonView,
		 addPersonUseCase: AddPersonUseCase,
		 fetchWidgetPersonsUseCase: FetchPersonsUseCase,
		 router: EditPersonViewRouter,
		 delegate: EditPersonPresenterDelegate?,
		 imagesCellPresenter: ImagesCellPresenter,
		 nameCellPresenter: TextFieldCellPresenter,
		 dateCellsPresenter: DateCellPresenter,
		 toggleCellPresenter: ToggleCellPresenter) {
		self.view = view
		self.addPersonUseCase = addPersonUseCase
		self.fetchWidgetPersonsUseCase = fetchWidgetPersonsUseCase
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
		view?.displayBarButton(with: .done)
		configureInitialStateForDatePickers()
		configureInitialStateForToggle()
	}

	private func configureInitialStateForDatePickers() {
		// The combined picker is always showing a value, so seed the birthday with the
		// current date and time. The user adjusts it; both day and time slots stay in
		// sync because the picker is a single control.
		let now = Date()
		dateCellsPresenter.valueFor(row: EPC.dayPickerRow, didChangeTo: now)
		dateCellsPresenter.valueFor(row: EPC.timePickerRow, didChangeTo: now)
	}

	private func configureInitialStateForToggle() {
		fetchWidgetPersonsUseCase.fetchWidgetPersons { result in
			switch result {
			case .success(let favs):
				let maxReached = favs.count >= 3
				self.toggleCellPresenter.valueFor(row: EPC.addToWidgetRow, didChangeTo: !maxReached)
			case .failure(let error):
				self.toggleCellPresenter.valueFor(row: EPC.addToWidgetRow, didChangeTo: false)
				Logging.logError(error)
			}
			self.view?.reloadData()
		}
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

	func removePersonPressed() {}

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
		return false
	}

	// MARK: - Private

	private func handlePersonAdded(_ person: Person) {
		delegate?.editPersonPresenter(self, didAdd: person)
	}

	private func handleAddPersonError(_ error: Error) {
		let coreError = error as? CoreError
		let title = coreError?.title ?? String(localized: "Error")
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
		let personPics = imagesCellPresenter.valueFor(row: EPC.imagePickerRow)
		let appPic = personPics?.appPic
		let widgetPic = personPics?.widgetPic
		let isOnWidget = toggleCellPresenter.valueFor(row: EPC.addToWidgetRow)
		return AddPersonParameters(name: name,
								   dayOfBirth: dayOfBirth,
								   timeOfBirth: timeOfBirth,
								   appImage: appPic,
								   widgetImage: widgetPic,
								   isOnWidget: isOnWidget )
	}
}

extension AddPersonPresenter: TextFieldObserver {

	func textDidChange(forView: TextFieldCellView, text: String) {
		view?.displayScreenTitle(title: text)
	}
}

extension AddPersonPresenter: ToggleCellDelegate {

	func toggle(toggle: ToggleCellView, didChangeStateForRow row: Int, to state: Bool) {
		toggleCellPresenter.valueFor(row: row, didChangeTo: state)
	}
}

extension AddPersonPresenter: DateCellDelegate {

	func dateCell(_ cell: DateCellView, didChangeBirthdayTo date: Date) {
		dateCellsPresenter.valueFor(row: EPC.dayPickerRow, didChangeTo: date)
		dateCellsPresenter.valueFor(row: EPC.timePickerRow, didChangeTo: date)
	}
}
