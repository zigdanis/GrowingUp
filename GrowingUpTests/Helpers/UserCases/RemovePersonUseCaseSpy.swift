//
//  RemovePersonUseCaseSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 24/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

@testable import Core

final class RemovePersonUseCaseSpy: RemovePersonUseCase {

	var didCallRemovePerson = false
	var resultToBeReturned: Result<Void, CoreError>!

	func remove(person: Person, completionHandler: @escaping RemovePersonUseCaseCompletionHandler) {
		didCallRemovePerson = true
		completionHandler(resultToBeReturned)
	}
}
