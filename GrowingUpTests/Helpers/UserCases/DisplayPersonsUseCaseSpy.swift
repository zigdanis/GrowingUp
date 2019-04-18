//
//  DisplayPersonsUseCaseSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

class DisplayPersonsUseCaseSpy: DisplayPersonsUseCase {

	var displayPersonsCalled = false
	var resultToBeReturned: Result<[Person], CoreError>!

	func fetchPersons(completionHandler: @escaping FetchPersonsUseCaseCompletionHandler) {
		displayPersonsCalled = true
		completionHandler(resultToBeReturned)
	}

}
