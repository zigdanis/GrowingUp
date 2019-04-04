//
//  AddPerson.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

typealias AddPersonUseCaseCompletionHandler = (_ person: Result<Person, CoreError>) -> Void

protocol AddPersonUseCase {
    func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonUseCaseCompletionHandler)
}

class AddPersonUseCaseImplementation: AddPersonUseCase {
    let personsGateway: PersonsGateway

    init(personsGateway: PersonsGateway) {
        self.personsGateway = personsGateway
    }

    func add(parameters: AddPersonParameters, completionHandler: @escaping (Result<Person, CoreError>) -> Void) {
        personsGateway.add(parameters: parameters) { (result) in
            completionHandler(result)
        }
    }

}
