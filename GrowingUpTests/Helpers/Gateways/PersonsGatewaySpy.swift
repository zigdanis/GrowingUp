//
//  PersonsGatewaySpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 16/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@testable import Core
@testable import GrowingUp

class PersonsGatewaySpy: PersonsGateway {

	var addPersonParameters: AddPersonParameters!
	var addPersonResultToBeReturned: Result<Person, CoreError>!
	var addPersonCalled = false
	var fetchPersonsCalled = false
	var fetchPersonsResultToBeReturned: Result<[Person], CoreError>!
	var editPersonCalled = false
	var editPersonResultToBeReturned: Result<Person, CoreError>!
	var removePersonCalled = false
	var removePersonResultToBeReturned: Result<Void, CoreError>!
	var onAdd: (() -> Void)?
	var onEdit: (() -> Void)?
	var onRemove: (() -> Void)?

	func add(parameters: AddPersonParameters) async throws -> Person {
		addPersonCalled = true
		addPersonParameters = parameters
		onAdd?()
		return try addPersonResultToBeReturned.get()
	}

	func fetchPersons() async throws -> [Person] {
		fetchPersonsCalled = true
		return try fetchPersonsResultToBeReturned.get()
	}

	func fetchWidgetPersons() async throws -> [Person] {
		try fetchPersonsResultToBeReturned.get()
	}

	func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person {
		editPersonCalled = true
		addPersonParameters = parameters
		onEdit?()
		return try editPersonResultToBeReturned.get()
	}

	func remove(person: Person) async throws {
		removePersonCalled = true
		onRemove?()
		try removePersonResultToBeReturned.get()
	}
}
