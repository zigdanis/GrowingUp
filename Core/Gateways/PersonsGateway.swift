//
//  PersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

public typealias AddPersonEntityGatewayCompletionHandler = (_ result: Result<Person, CoreError>) -> Void
public typealias EditPersonEntityGatewayCompletionHandler = (_ result: Result<Person, CoreError>) -> Void
public typealias FetchPersonsEntityGatewayCompletionHandler = (_ result: Result<[Person], CoreError>) -> Void
public typealias RemovePersonEntityGatewayCompletionHandler = (_ result: Result<Void, CoreError>) -> Void

public protocol PersonsGateway {
	func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler)
	func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler)
	func edit(
		person: Person, with parameters: AddPersonParameters,
		completionHandler: @escaping EditPersonEntityGatewayCompletionHandler)
	func remove(person: Person, completionHandler: @escaping RemovePersonEntityGatewayCompletionHandler)
	func fetchWidgetPersons(completion: @escaping FetchPersonsEntityGatewayCompletionHandler)
}
