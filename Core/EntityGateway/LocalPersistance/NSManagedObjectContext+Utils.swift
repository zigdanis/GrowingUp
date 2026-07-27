//
//  NSManagedObjectContext+Utils.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import CoreData
import Foundation

public protocol NSManagedObjectContextProtocol {
	func allEntities<T: NSManagedObject>(withType type: T.Type) throws -> [T]
	func allEntities<T: NSManagedObject>(withType type: T.Type, predicate: NSPredicate?) throws -> [T]
	func addEntity<T: NSManagedObject>(withType type: T.Type) -> T?
	func save() throws
	func delete(_ object: NSManagedObject)
}

extension NSManagedObjectContext: NSManagedObjectContextProtocol {
	public func allEntities<T: NSManagedObject>(withType type: T.Type) throws -> [T] {
		return try allEntities(withType: type, predicate: nil)
	}

	public func allEntities<T: NSManagedObject>(withType type: T.Type, predicate: NSPredicate?) throws -> [T] {
		let request = NSFetchRequest<T>(entityName: T.description())
		request.predicate = predicate
		let results = try self.fetch(request)

		return results
	}

	public func addEntity<T: NSManagedObject>(withType type: T.Type) -> T? {
		let entityName = T.description()

		guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: self) else {
			return nil
		}

		let record = T(entity: entity, insertInto: self)

		return record
	}
}
