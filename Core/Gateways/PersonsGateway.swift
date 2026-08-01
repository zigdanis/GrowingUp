//
//  PersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

public typealias AddPersonEntityGatewayCompletionHandler = (_ result: Result<Person, CoreError>) -> Void
public typealias EditPersonEntityGatewayCompletionHandler = (_ result: Result<Person, CoreError>) -> Void
public typealias FetchPersonsEntityGatewayCompletionHandler = (_ result: Result<[Person], CoreError>) -> Void
public typealias RemovePersonEntityGatewayCompletionHandler = (_ result: Result<Void, CoreError>) -> Void

public protocol PersonsGateway {
	func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler)
	func add(parameters: AddPersonParameters) async throws -> Person
	func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler)
	func fetchPersons() async throws -> [Person]
	func edit(
		person: Person, with parameters: AddPersonParameters,
		completionHandler: @escaping EditPersonEntityGatewayCompletionHandler)
	func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person
	func remove(person: Person, completionHandler: @escaping RemovePersonEntityGatewayCompletionHandler)
	func remove(person: Person) async throws
	func fetchWidgetPersons(completion: @escaping FetchPersonsEntityGatewayCompletionHandler)
	func fetchWidgetPersons() async throws -> [Person]
}

public extension PersonsGateway {

	func add(parameters: AddPersonParameters) async throws -> Person {
		try Task.checkCancellation()
		let person = try await withCheckedThrowingContinuation { continuation in
			add(parameters: parameters) { continuation.resume(with: $0) }
		}
		try Task.checkCancellation()
		return person
	}

	func fetchPersons() async throws -> [Person] {
		try Task.checkCancellation()
		let persons = try await withCheckedThrowingContinuation { continuation in
			fetchPersons { continuation.resume(with: $0) }
		}
		try Task.checkCancellation()
		return persons
	}

	func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person {
		try Task.checkCancellation()
		let person = try await withCheckedThrowingContinuation { continuation in
			edit(person: person, with: parameters) { continuation.resume(with: $0) }
		}
		try Task.checkCancellation()
		return person
	}

	func remove(person: Person) async throws {
		try Task.checkCancellation()
		try await withCheckedThrowingContinuation { continuation in
			remove(person: person) { continuation.resume(with: $0) }
		}
	}

	func fetchWidgetPersons() async throws -> [Person] {
		try Task.checkCancellation()
		let persons = try await withCheckedThrowingContinuation { continuation in
			fetchWidgetPersons { continuation.resume(with: $0) }
		}
		try Task.checkCancellation()
		return persons
	}
}
