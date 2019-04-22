//
//  AddPersonUseCaseSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

class EditPersonUseCaseSpy: EditPersonUseCase {

    var resultToBeReturned: Result<Person, CoreError>!
    var callCompletionHandlerImmediate = true
    var personToEditParameters: AddPersonParameters?
    private var completionHandler: EditPersonUseCaseCompletionHandler?

	func edit(person: Person, with parameters: AddPersonParameters, completionHandler: @escaping EditPersonUseCaseCompletionHandler) {
        personToEditParameters = parameters
        self.completionHandler = completionHandler
        if callCompletionHandlerImmediate {
            callCompletionHandler()
        }
    }

    func callCompletionHandler() {
        self.completionHandler?(resultToBeReturned)
    }

}
