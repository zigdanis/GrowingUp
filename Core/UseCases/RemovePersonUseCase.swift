//
//  RemovePersonUseCase.swift
//  Core
//
//  Created by zigdanis on 24/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

public typealias RemovePersonUseCaseCompletionHandler = (_ result: Result<Void, CoreError>) -> Void

public protocol RemovePersonUseCase {
	func remove(person: Person, completionHandler: @escaping RemovePersonUseCaseCompletionHandler)
	func remove(person: Person) async throws
}

public final class RemovePersonUseCaseImplementation: RemovePersonUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func remove(person: Person, completionHandler: @escaping RemovePersonUseCaseCompletionHandler) {
		personsGateway.remove(person: person, completionHandler: completionHandler)
	}

	public func remove(person: Person) async throws {
		try await personsGateway.remove(person: person)
	}
}
