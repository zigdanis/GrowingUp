//
//  RemovePersonUseCase.swift
//  Core
//
//  Created by zigdanis on 24/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public typealias RemovePersonUseCaseCompletionHandler = (_ result: Result<Void, CoreError>) -> Void

public protocol RemovePersonUseCase {
	func remove(person: Person, completionHandler: @escaping RemovePersonUseCaseCompletionHandler)
}

public final class RemovePersonUseCaseImplementation: RemovePersonUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func remove(person: Person, completionHandler: @escaping RemovePersonUseCaseCompletionHandler) {
		personsGateway.remove(person: person, completionHandler: completionHandler)
	}
}
