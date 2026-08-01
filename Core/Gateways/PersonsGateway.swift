//
//  PersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

public protocol PersonsGateway {
	func add(parameters: AddPersonParameters) async throws -> Person
	func fetchPersons() async throws -> [Person]
	func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person
	func remove(person: Person) async throws
	func fetchWidgetPersons() async throws -> [Person]
}
