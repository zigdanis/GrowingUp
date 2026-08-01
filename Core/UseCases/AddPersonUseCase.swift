//
//  AddPerson.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

public typealias AddPersonUseCaseCompletionHandler = (_ person: Result<Person, CoreError>) -> Void

public protocol AddPersonUseCase {
	func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonUseCaseCompletionHandler)
	func add(parameters: AddPersonParameters) async throws -> Person
}

public final class AddPersonUseCaseImplementation: AddPersonUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func add(parameters: AddPersonParameters, completionHandler: @escaping (Result<Person, CoreError>) -> Void) {
		personsGateway.add(parameters: parameters) { (result) in
			completionHandler(result)
		}
	}

	public func add(parameters: AddPersonParameters) async throws -> Person {
		try await personsGateway.add(parameters: parameters)
	}

}
