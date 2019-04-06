//
//  CoreDataPersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

class CoreDataPersonsGateway: PersonsGateway {

	let viewContext: NSManagedObjectContextProtocol

	init(viewContext: NSManagedObjectContextProtocol) {
		self.viewContext = viewContext
	}

	func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {
		guard let coreDataPerson = viewContext.addEntity(withType: CoreDataPerson.self) else {
			let result = Result<Person, CoreError>.failure(CoreError.coreDataAddFailed)
			return completionHandler(result)
		}

		coreDataPerson.populate(with: parameters)

		do {
			try viewContext.save()
			completionHandler(.success(coreDataPerson.person))
		} catch {
			viewContext.delete(coreDataPerson)
			completionHandler(.failure(CoreError.coreDataSaveFailed))
		}
	}

}
