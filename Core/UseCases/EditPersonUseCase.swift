//
//  EditPersonUseCase.swift
//  GrowingUp
//
//  Created by zigdanis on 16/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public typealias EditPersonUseCaseCompletionHandler = (_ person: Result<Person, CoreError>) -> Void

public protocol EditPersonUseCase {
	func edit(
		person: Person, with parameters: AddPersonParameters,
		completionHandler: @escaping EditPersonUseCaseCompletionHandler)
}

public final class EditPersonUseCaseImplementation: EditPersonUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func edit(
		person: Person, with parameters: AddPersonParameters,
		completionHandler: @escaping (Result<Person, CoreError>) -> Void
	) {
		personsGateway.edit(person: person, with: parameters) { (result) in
			completionHandler(result)
		}
	}

}
