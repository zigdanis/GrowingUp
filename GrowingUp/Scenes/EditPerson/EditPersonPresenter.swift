//
//  EditPersonPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol EditPersonPresenter: TextFieldObserver {
    var router: EditPersonViewRouter { get }
	func viewDidLoad()
    func addButtonPressed()
    func cancelButtonPressed()
	func configure(cell: ImagesCellView, forRow row: Int)
    func configure(cell: TextFieldCellView, forRow row: Int)
    func configure(cell: DateCellView, forRow row: Int)
    func configure(cell: SwitchCellView, forRow row: Int)
	func dateFor(row: Int, didUpdateTo date: Date)
	func appImagePicked(image: PersonImage)
	func widgetImagePicked(image: PersonImage)
}

protocol EditPersonPresenterDelegate: class {
    func editPersonPresenter(_ presenter: EditPersonPresenter, didAdd person: Person)
    func editPersonPresenterCancel(presenter: EditPersonPresenter)
}

final class EditPersonPresenterImplementation: EditPersonPresenter {

	private let type: IntentType
    private weak var view: EditPersonView?
    private let addPersonUseCase: AddPersonUseCase
    private weak var delegate: EditPersonPresenterDelegate?
    private(set) var router: EditPersonViewRouter
	private let imagesCellPresenter: ImagesCellPresenter
	private let nameCellPresenter: TextFieldCellPresenter
	private let dateCellsPresenter: DateCellPresenter
	private let dateComponentsCellsPresenter: SwitchCellPresenter

// swiftlint:disable vertical_parameter_alignment
	init(type: IntentType,
		 view: EditPersonView,
		 addPersonUseCase: AddPersonUseCase,
		 router: EditPersonViewRouter,
		 delegate: EditPersonPresenterDelegate?,
		 imagesCellPresenter: ImagesCellPresenter,
		 nameCellPresenter: TextFieldCellPresenter,
		 dateCellsPresenter: DateCellPresenter,
		 dateComponentsCellsPresenter: SwitchCellPresenter) {
		self.type = type
		self.view = view
		self.addPersonUseCase = addPersonUseCase
		self.router = router
		self.delegate = delegate
		self.imagesCellPresenter = imagesCellPresenter
		self.nameCellPresenter = nameCellPresenter
		self.dateCellsPresenter = dateCellsPresenter
		self.dateComponentsCellsPresenter = dateComponentsCellsPresenter
	}
// swiftlint:enable vertical_parameter_alignment

    // MARK: - EditPersonPresenter

	func viewDidLoad() {
		switch type {
		case .create:
			view?.displayBarButton(with: .cancel)
			view?.displayBarButton(with: .done)
		case .edit:
			view?.displayBarButton(with: .close)
			view?.displayBarButton(with: .save)
		}
	}

    func addButtonPressed() {
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

    func cancelButtonPressed() {
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
		var personPics = imagesCellPresenter.valueFor(row: APC.imagePickerRow) ?? PersonImages.emptyImages()
		personPics.appPic = image
		imagesCellPresenter.valueFor(row: APC.imagePickerRow, didChangeTo: personPics)
	}

	func widgetImagePicked(image: PersonImage) {
		var personPics = imagesCellPresenter.valueFor(row: APC.imagePickerRow) ?? PersonImages.emptyImages()
		personPics.widgetPic = image
		imagesCellPresenter.valueFor(row: APC.imagePickerRow, didChangeTo: personPics)
	}

    // MARK: - Private

    private func handlePersonAdded(_ person: Person) {
        delegate?.editPersonPresenter(self, didAdd: person)
    }

    private func handleAddPersonError(_ error: Error) {
		let coreError = error as? CoreError
		let title = coreError?.title ?? R.string.localizable.error()
		let message = coreError?.message ?? error.localizedDescription
        view?.displayAddPersonError(title: title, message: message)
    }

    private func updateNavigationItemsState(isEnabled enabled: Bool) {
        view?.updateAddButtonState(isEnabled: enabled)
        view?.updateCancelButtonState(isEnabled: enabled)
    }

	private func collectAddPersonParameters() throws -> AddPersonParameters {
		guard let name = nameCellPresenter.valueFor(row: APC.nameFieldRow), !name.isEmpty else {
			throw CoreError.noNameValue
		}
		guard let dayOfBirth = dateCellsPresenter.valueFor(row: APC.dayPickerRow) else {
			throw CoreError.noDayValue
		}
		guard let timeOfBirth = dateCellsPresenter.valueFor(row: APC.timePickerRow) else {
			throw CoreError.noTimeValue
		}
		let components = dateComponentsCellsPresenter.updatedComponents()
		let personPics = imagesCellPresenter.valueFor(row: APC.imagePickerRow)
		let appPic = personPics?.appPic
		let widgetPic = personPics?.widgetPic
		return AddPersonParameters(name: name,
								   dayOfBirth: dayOfBirth,
								   timeOfBirth: timeOfBirth,
								   dateComponenets: components,
								   appImage: appPic,
								   widgetImage: widgetPic)
	}
}

extension EditPersonPresenterImplementation: TextFieldObserver {

	func textDidChange(forView: TextFieldCellView, text: String) {
		view?.displayScreenTitle(title: text)
	}
}
