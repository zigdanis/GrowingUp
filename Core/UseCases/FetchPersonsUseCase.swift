//
//  DisplayPersonsUseCase.swift
//  GrowingUp
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

public typealias FetchPersonsUseCaseCompletionHandler = (_ persons: Result<[Person], CoreError>) -> Void

public protocol FetchPersonsUseCase {
	func fetchPersons(completionHandler: @escaping FetchPersonsUseCaseCompletionHandler)
	func fetchWidgetPersons(completion: @escaping FetchPersonsUseCaseCompletionHandler)
}

public final class FetchPersonsUseCaseImplementation: FetchPersonsUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	// MARK: - DisplayPersonsUseCase

	public func fetchPersons(completionHandler: @escaping (Result<[Person], CoreError>) -> Void) {
		self.personsGateway.fetchPersons { (result) in
			completionHandler(result)
		}
	}

	public func fetchWidgetPersons(completion: @escaping FetchPersonsUseCaseCompletionHandler) {
		personsGateway.fetchWidgetPersons(completion: completion)
	}
}
