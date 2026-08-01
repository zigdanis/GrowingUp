//
//  CoreDataPersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import CoreData
import Foundation

public class CoreDataPersonsGateway: PersonsGateway {

	let coreDataStack: CoreDataStack

	public init(coreDataStack: CoreDataStack) {
		self.coreDataStack = coreDataStack
	}

	public func add(parameters: AddPersonParameters) async throws -> Person {
		try Task.checkCancellation()
		return try await withCheckedThrowingContinuation { continuation in
			coreDataStack.persistentContainer.performBackgroundTask { context in
				guard let person = context.addEntity(withType: CoreDataPerson.self) else {
					continuation.resume(throwing: CoreError.coreDataAddFailed)
					return
				}
				do {
					person.populate(with: parameters)
					person.accessToWidget =
						parameters.isOnWidget
						? try AccessToWidget.sharedInstance(in: context) : nil
					try context.save()
					continuation.resume(returning: person.person)
				} catch let error as CoreError {
					context.delete(person)
					continuation.resume(throwing: error)
				} catch {
					context.delete(person)
					continuation.resume(throwing: CoreError(error: error))
				}
			}
		}
	}

	public func fetchPersons() async throws -> [Person] {
		try Task.checkCancellation()
		let persons = try await withCheckedThrowingContinuation { continuation in
			coreDataStack.persistentContainer.performBackgroundTask { context in
				let request: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
				request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: true)]
				do {
					continuation.resume(returning: try context.fetch(request).map(\.person))
				} catch {
					continuation.resume(throwing: CoreError(error: error))
				}
			}
		}
		try Task.checkCancellation()
		return persons
	}

	public func fetchWidgetPersons() async throws -> [Person] {
		try Task.checkCancellation()
		let persons = try await withCheckedThrowingContinuation { continuation in
			coreDataStack.persistentContainer.performBackgroundTask { context in
				do {
					guard let persons = try AccessToWidget.sharedInstance(in: context).widgetPersons else {
						throw CoreError.missingValue
					}
					continuation.resume(returning: persons.map(\.person).sorted())
				} catch let error as CoreError {
					continuation.resume(throwing: error)
				} catch {
					continuation.resume(throwing: CoreError(error: error))
				}
			}
		}
		try Task.checkCancellation()
		return persons
	}

	public func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person {
		try Task.checkCancellation()
		return try await withCheckedThrowingContinuation { continuation in
			coreDataStack.persistentContainer.performBackgroundTask { context in
				do {
					let request: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
					request.predicate = NSPredicate(
						format: "%K == %@", #keyPath(CoreDataPerson.id), person.id.uuidString)
					guard let storedPerson = try context.fetch(request).first else {
						throw CoreError.coreDataFetchFailed
					}
					storedPerson.populate(with: parameters)
					storedPerson.accessToWidget =
						parameters.isOnWidget
						? try AccessToWidget.sharedInstance(in: context) : nil
					try context.save()
					continuation.resume(returning: storedPerson.person)
				} catch let error as CoreError {
					continuation.resume(throwing: error)
				} catch {
					continuation.resume(throwing: CoreError(error: error))
				}
			}
		}
	}

	public func remove(person: Person) async throws {
		try Task.checkCancellation()
		try await withCheckedThrowingContinuation { continuation in
			coreDataStack.persistentContainer.performBackgroundTask { context in
				do {
					let request: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
					request.predicate = NSPredicate(
						format: "%K == %@", #keyPath(CoreDataPerson.id), person.id.uuidString)
					guard let storedPerson = try context.fetch(request).first else {
						throw CoreError.coreDataFetchFailed
					}
					context.delete(storedPerson)
					try context.save()
					continuation.resume(returning: ())
				} catch let error as CoreError {
					continuation.resume(throwing: error)
				} catch {
					continuation.resume(throwing: CoreError(error: error))
				}
			}
		}
	}
}
