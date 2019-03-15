//
//  AddPersonPresenterDelegateSpy.swift
//  AgingTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import Aging

class AddPersonPresenterDelegateSpy: AddPersonPresenterDelegate {
    
    var addedPerson: Person?
    var didCalledAddPerson = false
    var didCalledCancel = false
    
    func addPersonPresenter(_ presenter: AddPersonPresenter, didAdd person: Person) {
        didCalledAddPerson = true
        addedPerson = person
    }
    
    func addPersonPresenterCancel(presenter: AddPersonPresenter) {
        didCalledCancel = true
    }
    
    
}
