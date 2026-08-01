//
//  DisplayPersonsUseCase.swift
//  GrowingUp
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

public protocol FetchPersonsUseCase {
	func fetchPersons() async throws -> [Person]
	func fetchWidgetPersons() async throws -> [Person]
}

public final class FetchPersonsUseCaseImplementation: FetchPersonsUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func fetchPersons() async throws -> [Person] {
		try await personsGateway.fetchPersons()
	}

	public func fetchWidgetPersons() async throws -> [Person] {
		try await personsGateway.fetchWidgetPersons()
	}
}
