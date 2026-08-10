//
//  RemovePersonUseCaseSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 24/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@testable import Core

final class RemovePersonUseCaseSpy: RemovePersonUseCase {

	var didCallRemovePerson = false
	var resultToBeReturned: Result<Void, CoreError>!

	func remove(person: Person) async throws {
		didCallRemovePerson = true
		try resultToBeReturned.get()
	}
}
