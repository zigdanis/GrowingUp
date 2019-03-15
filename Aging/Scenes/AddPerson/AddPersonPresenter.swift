//
//  AddPersonPresenter.swift
//  Aging
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol AddPersonPresenter {
    var router: AddPersonViewRouter { get }
    func addButtonPressed(parameters: AddPersonParameters)
    func cancelButtonPressed()
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
    
    init(view: AddPersonView,
         addPersonUseCase: AddPersonUseCase,
         router: AddPersonViewRouter,
         delegate: AddPersonPresenterDelegate?) {
        self.view = view
        self.addPersonUseCase = addPersonUseCase
        self.router = router
        self.delegate = delegate
    }
    
    
    func addButtonPressed(parameters: AddPersonParameters) {
        router.dismiss()
        view?.updateAddButtonState(isEnabled: false)
        view?.updateCancelButtonState(isEnabled: false)
        addPersonUseCase.add(parameters: parameters) { result in
            switch result {
            case let .success(person):
                self.handlePersonAdded(person)
            case let .failure(error):
                self.handleAddPersonError(error)
            }
        }
    }
    
    func cancelButtonPressed() {
        router.dismiss()
    }
    
    // MARK: - Private
    
    private func handlePersonAdded(_ person: Person) {
        
    }
    
    private func handleAddPersonError(_ error: CoreError) {
        view?.displayAddPersonError(title: error.title, message: error.message)
    }
}
