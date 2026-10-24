//
//  PersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

public protocol PersonsGateway {
	func add(parameters: AddPersonParameters) async throws -> Person
	func fetchPersons() async throws -> [Person]
	func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person
	func remove(person: Person) async throws
	func fetchWidgetPersons() async throws -> [Person]
	/// Stores `ids` as the mosaic order; people missing from `ids` keep their order after them.
	func reorder(_ ids: [UUID]) async throws
}
