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
    func addButtonPressed(parameters: AddPersonParameters)
    func cancelButtonPressed()
    func configure(cell: TextFieldCellView, forRow row: Int)
    func configure(cell: LabelCellView, forRow row: Int)
    func configure(cell: SwitchCellView, forRow row: Int)
}

protocol AddPersonPresenterDelegate: class {
    func addPersonPresenter(_ presenter: AddPersonPresenter, didAdd person: Person)
    func addPersonPresenterCancel(presenter: AddPersonPresenter)
}

class AddPersonPresenterImplementation: AddPersonPresenter {

    private weak var view: AddPersonView?
    private var addPersonUseCase: AddPersonUseCase
    private weak var delegate: AddPersonPresenterDelegate?
    private(set) var router: AddPersonViewRouter
    private var addPersonName: String?
    private var addPersonDateOfBirth: Date?
    private var addPersonTimeOfBirth: Date?
    private var addPersonDateComponents = AddPersonDateComponents()
    
    init(view: AddPersonView,
         addPersonUseCase: AddPersonUseCase,
         router: AddPersonViewRouter,
         delegate: AddPersonPresenterDelegate?) {
        self.view = view
        self.addPersonUseCase = addPersonUseCase
        self.router = router
        self.delegate = delegate
    }
    
    // MARK: - AddPersonPresenter
    
    func addButtonPressed(parameters: AddPersonParameters) {
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
        cell.display(title: R.string.localizable.name())
        cell.display(placeholder: R.string.localizable.name())
        guard let personName = addPersonName else { return }
        cell.display(value: personName)
    }
    
    func configure(cell: LabelCellView, forRow row: Int) {
        switch row {
        case 1:
            cell.display(title: R.string.localizable.dateOfBirth())
            let value = addPersonDateOfBirth?.dateString() ?? "xx.xx.xxxx"
            cell.display(value: value)
        case 2:
            cell.display(title: R.string.localizable.timeOfBirth())
            let value = addPersonTimeOfBirth?.timeString() ?? "xx:xx"
            cell.display(value: value)
        default:
            assertionFailure("We support LabelCellView only for rows in [1...2]")
        }
    }
    
    func configure(cell: SwitchCellView, forRow row: Int) {
        switch row {
        case 3:
            cell.display(title: R.string.localizable.showYears())
            cell.setSwitch(isOn: addPersonDateComponents.years)
        case 4:
            cell.display(title: R.string.localizable.showMonths())
            cell.setSwitch(isOn: addPersonDateComponents.months)
        case 5:
            cell.display(title: R.string.localizable.showDays())
            cell.setSwitch(isOn: addPersonDateComponents.days)
        case 6:
            cell.display(title: R.string.localizable.showHours())
            cell.setSwitch(isOn: addPersonDateComponents.hours)
        case 7:
            cell.display(title: R.string.localizable.showMinutes())
            cell.setSwitch(isOn: addPersonDateComponents.minutes)
        case 8:
            cell.display(title: R.string.localizable.showSeconds())
            cell.setSwitch(isOn: addPersonDateComponents.seconds)
        default:
            assertionFailure("We support SwitchCellView only for rows in [3...8]")
        }
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
}
