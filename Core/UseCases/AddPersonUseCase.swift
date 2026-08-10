//
//  AddPerson.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

public protocol AddPersonUseCase {
	func add(parameters: AddPersonParameters) async throws -> Person
}

public final class AddPersonUseCaseImplementation: AddPersonUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func add(parameters: AddPersonParameters) async throws -> Person {
		try await personsGateway.add(parameters: parameters)
	}
}
