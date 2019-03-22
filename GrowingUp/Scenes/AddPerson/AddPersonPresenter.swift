//
//  AddPersonPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol AddPersonPresenter {
    var router: AddPersonViewRouter { get }
    func addButtonPressed()
    func cancelButtonPressed()
    func configure(cell: TextFieldCellView, forRow row: Int)
    func configure(cell: DateCellView, forRow row: Int)
    func configure(cell: SwitchCellView, forRow row: Int)
	func dateFor(row: Int, didUpdateTo date: Date)
}

protocol AddPersonPresenterDelegate: class {
    func addPersonPresenter(_ presenter: AddPersonPresenter, didAdd person: Person)
    func addPersonPresenterCancel(presenter: AddPersonPresenter)
}

final class AddPersonPresenterImplementation: AddPersonPresenter {

    private weak var view: AddPersonView?
    private var addPersonUseCase: AddPersonUseCase
    private weak var delegate: AddPersonPresenterDelegate?
    private(set) var router: AddPersonViewRouter
	private let nameCellPresenter: TextFieldCellPresenter
	private let dateCellsPresenter: DateCellPresenter
	private let dateComponentsCellsPresenter: SwitchCellPresenter
    
    init(view: AddPersonView,
         addPersonUseCase: AddPersonUseCase,
         router: AddPersonViewRouter,
         delegate: AddPersonPresenterDelegate?,
		 nameCellPresenter: TextFieldCellPresenter,
		 dateCellsPresenter: DateCellPresenter,
		 dateComponentsCellsPresenter: SwitchCellPresenter) {
        self.view = view
        self.addPersonUseCase = addPersonUseCase
        self.router = router
        self.delegate = delegate
		self.nameCellPresenter = nameCellPresenter
		self.dateCellsPresenter = dateCellsPresenter
		self.dateComponentsCellsPresenter = dateComponentsCellsPresenter
    }
    
    // MARK: - AddPersonPresenter

    func addButtonPressed() {
		var params: AddPersonParameters?
		do {
			params = try collectAddPersonParameters()
		} catch {
			handleAddPersonError(error as! CoreError)
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
        delegate?.addPersonPresenterCancel(presenter: self)
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
    
    // MARK: - Private
    
    private func handlePersonAdded(_ person: Person) {
        delegate?.addPersonPresenter(self, didAdd: person)
    }
    
    private func handleAddPersonError(_ error: CoreError) {
        view?.displayAddPersonError(title: error.title, message: error.message)
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
		return AddPersonParameters(name: name,
								   dayOfBirth: dayOfBirth,
								   timeOfBirth: timeOfBirth,
								   dateComponenets: components)
	}
}
