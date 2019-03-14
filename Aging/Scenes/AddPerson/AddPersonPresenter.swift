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
