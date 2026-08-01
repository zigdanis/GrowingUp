//
//  AddPersonUseCaseSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@testable import Core
@testable import GrowingUp

class EditPersonUseCaseSpy: EditPersonUseCase {

	var resultToBeReturned: Result<Person, CoreError>!
	var callCompletionHandlerImmediate = true
	var personToEditParameters: AddPersonParameters?
	private var continuation: CheckedContinuation<Person, Error>?

	func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person {
		personToEditParameters = parameters
		if callCompletionHandlerImmediate { return try resultToBeReturned.get() }
		return try await withCheckedThrowingContinuation { continuation in
			self.continuation = continuation
		}
	}

	func callCompletionHandler() {
		continuation?.resume(with: resultToBeReturned.mapError { $0 as Error })
		continuation = nil
	}
}
