//
//  CoreDataPersonsGatewaySpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 06/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

class CoreDataPersonsGatewaySpy: CoreDataPersonsGateway {

	var addWithContextCalled = false
	var addCalled = false

	func add(parameters: AddPersonParameters, with context: NSManagedObjectContextProtocol) -> Result<Person, CoreError> {
		addWithContextCalled = true
		return .failure(CoreError.unknownError)
	}

	func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {
		addCalled = true
	}
}
