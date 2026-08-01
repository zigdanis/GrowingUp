//
//  DisplayPersonsUseCaseSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@testable import Core
@testable import GrowingUp

class DisplayPersonsUseCaseSpy: FetchPersonsUseCase {

	var displayPersonsCalled = false
	var resultToBeReturned: Result<[Person], CoreError>!

	func fetchPersons() async throws -> [Person] {
		displayPersonsCalled = true
		return try resultToBeReturned.get()
	}

	func fetchWidgetPersons() async throws -> [Person] {
		try resultToBeReturned.get()
	}
}
