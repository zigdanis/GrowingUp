//
//  PersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

typealias AddPersonEntityGatewayCompletionHandler = (_ person: Result<Person, CoreError>) -> Void
typealias FetchPersonsEntityGatewayCompletionHandler = (_ books: Result<[Person], CoreError>) -> Void

protocol PersonsGateway {
    func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler)
	func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler)
}
