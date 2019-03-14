//
//  PersonsGateway.swift
//  Aging
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

typealias FetchPersonsEntityGatewayCompletionHandler = (_ persons: Result<[Person]>) -> Void
typealias AddPersonEntityGatewayCompletionHandler = (_ person: Result<Person>) -> Void
typealias DeletePersonEntityGatewayCompletionHandler = (_ person: Result<Void>) -> Void

protocol PersonsGateway {
    func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler)
    func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler)
    func delete(person: Person, completionHandler: @escaping DeletePersonEntityGatewayCompletionHandler)
}
