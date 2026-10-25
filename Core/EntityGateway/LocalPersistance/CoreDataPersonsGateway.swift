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

	/// The mosaic order: by `displayOrder`, and people never reordered, who share 0, by `createdDate`.
	private static let mosaicOrder = [
		NSSortDescriptor(key: #keyPath(CoreDataPerson.displayOrder), ascending: true),
		NSSortDescriptor(key: #keyPath(CoreDataPerson.createdDate), ascending: true)
	]

	/// Keeps a new person's place at the end and a reordering from interleaving: each reads the stored order and then
	/// saves, so one must finish before the other starts.
	private static let orderLock = NSLock()

	let coreDataStack: CoreDataStack

	public init(coreDataStack: CoreDataStack) {
		self.coreDataStack = coreDataStack
	}

	public func add(parameters: AddPersonParameters) async throws -> Person {
		try Task.checkCancellation()
		let container = try coreDataStack.persistentContainer
		return try await withCheckedThrowingContinuation { continuation in
			container.performBackgroundTask { context in
				Self.orderLock.lock()
				defer { Self.orderLock.unlock() }
				// Read before the insert, so the new person's own default order is not counted.
				let lastOrder: Int64
				do {
					lastOrder = try Self.lastDisplayOrder(in: context)
				} catch {
					continuation.resume(throwing: CoreError(error: error))
					return
				}
				guard let person = context.addEntity(withType: CoreDataPerson.self) else {
					continuation.resume(throwing: CoreError.coreDataAddFailed)
					return
				}
				do {
					person.populate(with: parameters)
					// A new person joins the end of the mosaic, after any reordered people.
					person.displayOrder = lastOrder + 1
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
		let container = try coreDataStack.persistentContainer
		let persons = try await withCheckedThrowingContinuation { continuation in
			container.performBackgroundTask { context in
				let request: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
				request.sortDescriptors = Self.mosaicOrder
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
		let container = try coreDataStack.persistentContainer
		let persons = try await withCheckedThrowingContinuation { continuation in
			container.performBackgroundTask { context in
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
		let container = try coreDataStack.persistentContainer
		return try await withCheckedThrowingContinuation { continuation in
			container.performBackgroundTask { context in
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

	public func reorder(_ ids: [UUID]) async throws {
		try Task.checkCancellation()
		let container = try coreDataStack.persistentContainer
		try await withCheckedThrowingContinuation { continuation in
			container.performBackgroundTask { context in
				Self.orderLock.lock()
				defer { Self.orderLock.unlock() }
				do {
					let request: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
					request.sortDescriptors = Self.mosaicOrder
					let storedPeople = try context.fetch(request)
					let peopleByID = Dictionary(storedPeople.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
					let listed = try ids.map { id in
						guard let person = peopleByID[id.uuidString] else { throw CoreError.coreDataFetchFailed }
						return person
					}
					let listedIDs = Set(ids.map(\.uuidString))
					let unlisted = storedPeople.filter { !listedIDs.contains($0.id ?? "") }
					for (index, person) in (listed + unlisted).enumerated() {
						person.displayOrder = Int64(index + 1)
					}
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

	public func remove(person: Person) async throws {
		try Task.checkCancellation()
		let container = try coreDataStack.persistentContainer
		try await withCheckedThrowingContinuation { continuation in
			container.performBackgroundTask { context in
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

	/// The highest stored `displayOrder`, or 0 without people.
	private static func lastDisplayOrder(in context: NSManagedObjectContext) throws -> Int64 {
		let request: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(key: #keyPath(CoreDataPerson.displayOrder), ascending: false)]
		request.fetchLimit = 1
		return try context.fetch(request).first?.displayOrder ?? 0
	}
}
