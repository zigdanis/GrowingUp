//
//  PersonsGatewaySpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 16/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

class PersonsGatewaySpy: PersonsGateway {

    var addPersonParameters: AddPersonParameters!
    var addPersonResultToBeReturned: Result<Person, CoreError>!
	var fetchPersonsCalled = false
	var fetchPersonsResultToBeReturned: Result<[Person], CoreError>!

    func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {
        addPersonParameters = parameters
        completionHandler(addPersonResultToBeReturned)
    }

	func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		fetchPersonsCalled = true
		completionHandler(fetchPersonsResultToBeReturned)
	}
}
