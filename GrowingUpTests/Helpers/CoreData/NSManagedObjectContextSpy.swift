//
//  NSManagedObjectContextSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import CoreData
import Foundation

@testable import Core
@testable import GrowingUp

class NSManagedObjectContextSpy: NSManagedObjectContextProtocol {
	var fetchErrorToThrow: Error?
	var entitiesToReturn: [Any]?
	var addEntityToReturn: Any?
	var saveErrorToReturn: Error?
	var deletedObject: NSManagedObject?

	func allEntities<T: NSManagedObject>(withType type: T.Type) throws -> [T] {
		return try allEntities(withType: type, predicate: nil)
	}

	func allEntities<T: NSManagedObject>(withType type: T.Type, predicate: NSPredicate?) throws -> [T] {
		if let fetchErrorToThrow = fetchErrorToThrow {
			throw fetchErrorToThrow
		} else {
			return entitiesToReturn as! [T]  // swiftlint:disable:this force_cast
		}
	}

	func addEntity<T: NSManagedObject>(withType type: T.Type) -> T? {
		return addEntityToReturn as? T
	}

	func save() throws {
		if let saveErrorToReturn = saveErrorToReturn {
			throw saveErrorToReturn
		}
	}

	func delete(_ object: NSManagedObject) {
		deletedObject = object
	}
}
