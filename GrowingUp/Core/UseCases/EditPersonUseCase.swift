//
//  EditPersonUseCase.swift
//  GrowingUp
//
//  Created by zigdanis on 16/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

typealias EditPersonUseCaseCompletionHandler = (_ person: Result<Person, CoreError>) -> Void

protocol EditPersonUseCase {
	func edit(person: Person, with parameters: AddPersonParameters, completionHandler: @escaping EditPersonUseCaseCompletionHandler)
}

final class EditPersonUseCaseImplementation: EditPersonUseCase {
	let personsGateway: PersonsGateway

	init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	func edit(person: Person, with parameters: AddPersonParameters, completionHandler: @escaping (Result<Person, CoreError>) -> Void) {
		personsGateway.edit(person: person, with: parameters) { (result) in
			completionHandler(result)
		}
	}

}
