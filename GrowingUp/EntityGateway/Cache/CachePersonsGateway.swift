//
//  CachePersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 02/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import Disk

class CachePersonsGateway: PersonsGateway {

	let coreDataGateway: CoreDataPersonsGateway

	init(coreDataGateway: CoreDataPersonsGateway) {
		self.coreDataGateway = coreDataGateway
	}

	func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {

		// TaskManager save App Pic
		// TaskManager save widget Pic
		// TaskManager save Person to CoreData

		// Call me when you will finish with all of that
		coreDataGateway.add(parameters: parameters, completionHandler: completionHandler)
	}

}
