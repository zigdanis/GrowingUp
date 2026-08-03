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

class AddPersonUseCaseSpy: AddPersonUseCase {

	var resultToBeReturned: Result<Person, CoreError>!
	var callCompletionHandlerImmediate = true
	var personToAddParameters: AddPersonParameters?
	private var continuation: CheckedContinuation<Person, Error>?

	func add(parameters: AddPersonParameters) async throws -> Person {
		personToAddParameters = parameters
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
