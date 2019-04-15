//
//  EditPersonPresenterDelegateSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

class EditPersonPresenterDelegateSpy: EditPersonPresenterDelegate {

    var addedPerson: Person?
    var didCalledAddPerson = false
    var didCalledCancel = false

    func editPersonPresenter(_ presenter: EditPersonPresenter, didAdd person: Person) {
        didCalledAddPerson = true
        addedPerson = person
    }

	func editPersonPresenterCancel(presenter: EditPersonPresenter) {
        didCalledCancel = true
    }

}
