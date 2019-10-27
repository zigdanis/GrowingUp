//
//  CoreDataPersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import CoreData

public typealias FetchedPersonsCompletionHandler = (_ persons: Result<[Person], CoreError>) -> Void
public typealias FetchedPersonCompletionHandler = (_ person: Result<Person, CoreError>) -> Void

public class CoreDataPersonsGateway: PersonsGateway {

	let coreDataStack: CoreDataStack

	public init(coreDataStack: CoreDataStack) {
		self.coreDataStack = coreDataStack
	}

	public func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {
		coreDataStack.persistentContainer.performBackgroundTask { context in
			var result: Result<Person, CoreError> = .failure(CoreError.coreDataAddFailed)
			if let cdPerson = context.addEntity(withType: CoreDataPerson.self) {
				cdPerson.populate(with: parameters)
				do {
					if parameters.isOnWidget {
						cdPerson.accessToWidget = try AccessToWidget.sharedInstance(in: context)
					} else {
						cdPerson.accessToWidget = nil
					}
					try context.save()
					result = .success(cdPerson.person)
				} catch let error as CoreError {
					context.delete(cdPerson)
					result = .failure(error)
				} catch {
					context.delete(cdPerson)
					result = .failure(CoreError.coreDataSaveFailed)
				}
			}
			DispatchQueue.main.async {
				completionHandler(result)
			}
		}
	}

	public func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		coreDataStack.persistentContainer.performBackgroundTask { _ in
			var result: Result<[Person], CoreError> = .failure(.unknownError)
			let fetchRequest: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
			fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: true)]
			do {
				let persons = try fetchRequest.execute().map({ $0.person })
				result = .success(persons)
			} catch {
				let coreError = CoreError(error: error)
				result = .failure(coreError)
			}
			DispatchQueue.main.async {
				completionHandler(result)
			}
		}
	}

	public func edit(person: Person, with parameters: AddPersonParameters, completionHandler: @escaping EditPersonEntityGatewayCompletionHandler) {
		coreDataStack.persistentContainer.performBackgroundTask { context in
			var result: Result<Person, CoreError> = .failure(CoreError.unknownError)
			do {
				let predicate = NSPredicate(format: "%K == %@", #keyPath(CoreDataPerson.id), person.id.uuidString)
				let fetchRequest: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
				fetchRequest.predicate = predicate
				let coreDataPerson = try fetchRequest.execute().first
				guard let cdPerson = coreDataPerson else {
					throw CoreError.coreDataFetchFailed
				}
				cdPerson.populate(with: parameters)
				if parameters.isOnWidget {
					cdPerson.accessToWidget = try AccessToWidget.sharedInstance(in: context)
				} else {
					cdPerson.accessToWidget = nil
				}
				try context.save()
				result = .success(cdPerson.person)
			} catch let coreError as CoreError {
				result = .failure(coreError)
			} catch {
				let coreError = CoreError(error: error)
				result = .failure(coreError)
			}
			DispatchQueue.main.async {
				completionHandler(result)
			}
		}
	}

	public func remove(person: Person, completionHandler: @escaping RemovePersonEntityGatewayCompletionHandler) {
		coreDataStack.persistentContainer.performBackgroundTask { context in
			var result: Result<Void, CoreError> = .failure(.unknownError)
			do {
				let predicate = NSPredicate(format: "%K == %@", #keyPath(CoreDataPerson.id), person.id.uuidString)
				let fetchRequest: NSFetchRequest<CoreDataPerson> = CoreDataPerson.fetchRequest()
				fetchRequest.predicate = predicate
				let coreDataPerson = try fetchRequest.execute().first
				guard let cdPerson = coreDataPerson else {
					throw CoreError.coreDataFetchFailed
				}
				context.delete(cdPerson)
				try context.save()
				result = .success(())
			} catch let error as CoreError {
				result = .failure(error)
			} catch {
				let coreError = CoreError(error: error)
				result = .failure(coreError)
			}
			DispatchQueue.main.async {
				completionHandler(result)
			}
		}
	}

	public func fetchWidgetPersons(completion: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		coreDataStack.persistentContainer.performBackgroundTask { _ in
			var result: Result<[Person], CoreError> = .failure(.unknownError)
			do {
				let fetch: NSFetchRequest<AccessToWidget> = AccessToWidget.fetchRequest()
				let access = try fetch.execute().first
				guard let persons = access?.widgetPersons else {
					throw CoreError.missingValue
				}
				let cdPersons = Array(persons.map({ $0.person }))
				result = .success(cdPersons)
			} catch let error as CoreError {
				result = .failure(error)
			} catch {
				let coreError = CoreError(error: error)
				result = .failure(coreError)
			}
			DispatchQueue.main.async {
				completion(result)
			}
		}
	}
}
