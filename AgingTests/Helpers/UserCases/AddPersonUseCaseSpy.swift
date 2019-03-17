//
//  AddPersonUseCaseSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

class AddPersonUseCaseSpy: AddPersonUseCase {
    
    var resultToBeReturned: Result<Person>!
    var callCompletionHandlerImmediate = true
    var personToAddParameters: AddPersonParameters?
    private var completionHandler: AddPersonUseCaseCompletionHandler?
    
    func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonUseCaseCompletionHandler) {
        personToAddParameters = parameters
        self.completionHandler = completionHandler
        if callCompletionHandlerImmediate {
            callCompletionHandler()
        }
    }
    
    func callCompletionHandler() {
        self.completionHandler?(resultToBeReturned)
    }
    
}
