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
	private var completionHandler: EditPersonUseCaseCompletionHandler?

	func edit(
		person: Person, with parameters: AddPersonParameters,
		completionHandler: @escaping EditPersonUseCaseCompletionHandler
	) {
		personToEditParameters = parameters
		self.completionHandler = completionHandler
		if callCompletionHandlerImmediate {
			callCompletionHandler()
		}
	}

	func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person {
		try await withCheckedThrowingContinuation { continuation in
			edit(person: person, with: parameters) { continuation.resume(with: $0) }
		}
	}

	func callCompletionHandler() {
		self.completionHandler?(resultToBeReturned)
	}

}
