//
//  EditPersonPresenterDelegateSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

class EditPersonPresenterDelegateSpy: EditPersonPresenterDelegate {

    var addedPerson: Person?
	var editedPerson: Person?
	var removedPerson: Person?
    var didCalledAddPerson = false
	var didCalledEditPerson = false
	var didCalledRemovePerson = false
    var didCalledCancel = false

    func editPersonPresenter(_ presenter: EditPersonPresenter, didAdd person: Person) {
        didCalledAddPerson = true
        addedPerson = person
    }

	func editPersonPresenter(_ presenter: EditPersonPresenter, didEdit person: Person) {
		didCalledEditPerson = true
		editedPerson = person
	}

	func editPersonPresenter(_ presenter: EditPersonPresenter, didRemove person: Person) {
		removedPerson = person
		didCalledRemovePerson = true
	}

	func editPersonPresenterCancel(presenter: EditPersonPresenter) {
        didCalledCancel = true
    }

}
