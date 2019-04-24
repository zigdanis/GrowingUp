//
//  CoreDataPersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public protocol CoreDataPersonsGateway: PersonsGateway {
	func add(parameters: AddPersonParameters, with context: NSManagedObjectContextProtocol) -> Result<Person, CoreError>
	func edit(person: Person, with parameters: AddPersonParameters, with context: NSManagedObjectContextProtocol) -> Result<Person, CoreError>
	func fetchPersons(with context: NSManagedObjectContextProtocol) -> Result<[Person], CoreError>
	func remove(person: Person, with context: NSManagedObjectContextProtocol) -> Result<Void, CoreError>
}

public final class CoreDataPersonsGatewayImplementation: CoreDataPersonsGateway {

	let viewContext: NSManagedObjectContextProtocol

	public init(viewContext: NSManagedObjectContextProtocol) {
		self.viewContext = viewContext
	}

	public func add(parameters: AddPersonParameters, with context: NSManagedObjectContextProtocol) -> Result<Person, CoreError> {
		guard let coreDataPerson = context.addEntity(withType: CoreDataPerson.self) else {
			return .failure(CoreError.coreDataAddFailed)
		}

		coreDataPerson.populate(with: parameters)

		do {
			try context.save()
			return .success(coreDataPerson.person)
		} catch let error as CoreError {
			context.delete(coreDataPerson)
			return .failure(error)
		} catch {
			context.delete(coreDataPerson)
			return .failure(CoreError.coreDataSaveFailed)
		}
	}

	public func edit(person: Person, with parameters: AddPersonParameters, with context: NSManagedObjectContextProtocol) -> Result<Person, CoreError> {
		var coreDataPerson: CoreDataPerson?
		do {
			let predicate = NSPredicate(format: "%K == %@", #keyPath(CoreDataPerson.id), person.id as CVarArg)
			coreDataPerson = try context.allEntities(withType: CoreDataPerson.self, predicate: predicate).first
		} catch let error as CoreError {
			return .failure(error)
		} catch {
			return .failure(CoreError.coreDataFetchFailed)
		}

		guard let cdPerson = coreDataPerson else {
			return .failure(CoreError.coreDataFetchFailed)
		}
		cdPerson.populate(with: parameters)

		do {
			try context.save()
			return .success(cdPerson.person)
		} catch let error as CoreError {
			return .failure(error)
		} catch {
			return .failure(CoreError.coreDataSaveFailed)
		}
	}

	public func fetchPersons(with context: NSManagedObjectContextProtocol) -> Result<[Person], CoreError> {
		do {
			let coreDataPersons = try context.allEntities(withType: CoreDataPerson.self)
			let persons = coreDataPersons.map { $0.person }
			return .success(persons)
		} catch let error as CoreError {
			return .failure(error)
		} catch {
			return .failure(CoreError.coreDataFetchFailed)
		}
	}

	public func remove(person: Person, with context: NSManagedObjectContextProtocol) -> Result<Void, CoreError> {
		var coreDataPerson: CoreDataPerson?
		do {
			let predicate = NSPredicate(format: "%K == %@", #keyPath(CoreDataPerson.id), person.id as CVarArg)
			coreDataPerson = try context.allEntities(withType: CoreDataPerson.self, predicate: predicate).first
		} catch let error as CoreError {
			return .failure(error)
		} catch {
			return .failure(CoreError.coreDataFetchFailed)
		}

		guard let cdPerson = coreDataPerson else {
			return .failure(CoreError.coreDataFetchFailed)
		}
		context.delete(cdPerson)

		do {
			try context.save()
			return .success(())
		} catch let error as CoreError {
			return .failure(error)
		} catch {
			return .failure(CoreError.coreDataSaveFailed)
		}
	}

	public func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {
		let result = add(parameters: parameters, with: viewContext)
		completionHandler(result)
	}

	public func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		let result = fetchPersons(with: viewContext)
		completionHandler(result)
	}

	public func edit(person: Person, with parameters: AddPersonParameters, completionHandler: @escaping EditPersonEntityGatewayCompletionHandler) {
		let result = edit(person: person, with: parameters, with: viewContext)
		completionHandler(result)
	}

	public func remove(person: Person, completionHandler: @escaping RemovePersonEntityGatewayCompletionHandler) {
		let result = remove(person: person, with: viewContext)
		completionHandler(result)
	}

}
