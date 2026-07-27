//
//  PersonsGatewaySpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 16/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

@testable import Core
@testable import GrowingUp

class PersonsGatewaySpy: PersonsGateway {

	var addPersonParameters: AddPersonParameters!
	var addPersonResultToBeReturned: Result<Person, CoreError>!
	var addPersonCalled = false
	var fetchPersonsCalled = false
	var fetchPersonsResultToBeReturned: Result<[Person], CoreError>!
	var editPersonCalled = false
	var editPersonResultToBeReturned: Result<Person, CoreError>!
	var removePersonCalled = false
	var removePersonResultToBeReturned: Result<Void, CoreError>!

	func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {
		addPersonCalled = true
		addPersonParameters = parameters
		completionHandler(addPersonResultToBeReturned)
	}

	func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		fetchPersonsCalled = true
		completionHandler(fetchPersonsResultToBeReturned)
	}

	func fetchWidgetPersons(completion: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		completion(fetchPersonsResultToBeReturned)
	}

	func edit(
		person: Person, with parameters: AddPersonParameters,
		completionHandler: @escaping EditPersonEntityGatewayCompletionHandler
	) {
		editPersonCalled = true
		addPersonParameters = parameters
		completionHandler(editPersonResultToBeReturned)
	}

	func remove(person: Person, completionHandler: @escaping RemovePersonEntityGatewayCompletionHandler) {
		removePersonCalled = true
		completionHandler(removePersonResultToBeReturned)
	}
}
