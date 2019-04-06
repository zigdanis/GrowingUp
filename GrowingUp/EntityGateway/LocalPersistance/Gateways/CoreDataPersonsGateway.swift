//
//  CoreDataPersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol CoreDataPersonsGateway: PersonsGateway {
	func add(parameters: AddPersonParameters, with context: NSManagedObjectContextProtocol) -> Result<Person, CoreError>
}

final class CoreDataPersonsGatewayImplementation: CoreDataPersonsGateway {

	let viewContext: NSManagedObjectContextProtocol

	init(viewContext: NSManagedObjectContextProtocol) {
		self.viewContext = viewContext
	}

	func add(parameters: AddPersonParameters, with context: NSManagedObjectContextProtocol) -> Result<Person, CoreError> {
		guard let coreDataPerson = context.addEntity(withType: CoreDataPerson.self) else {
			return .failure(CoreError.coreDataAddFailed)
		}

		coreDataPerson.populate(with: parameters)

		do {
			try context.save()
			return .success(coreDataPerson.person)
		} catch {
			context.delete(coreDataPerson)
			return .failure(CoreError.coreDataSaveFailed)
		}

	}

	func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {
		let result = add(parameters: parameters, with: viewContext)
		completionHandler(result)
	}

}
