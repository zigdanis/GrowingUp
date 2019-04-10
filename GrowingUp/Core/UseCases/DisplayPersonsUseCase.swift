//
//  DisplayPersonsUseCase.swift
//  GrowingUp
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

typealias DisplayPersonsUseCaseCompletionHandler = (_ persons: Result<[Person], CoreError>) -> Void

protocol DisplayPersonsUseCase {
	func displayPersons(completionHandler: @escaping DisplayPersonsUseCaseCompletionHandler)
}

final class DisplayPersonsUseCaseImplementation: DisplayPersonsUseCase {
	let personsGateway: PersonsGateway

	init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	// MARK: - DisplayPersonsUseCase

	func displayPersons(completionHandler: @escaping (Result<[Person], CoreError>) -> Void) {
		self.personsGateway.fetchPersons { (result) in
			completionHandler(result)
		}
	}
}
