//
//  AccessToWidget+CoreDataClass.swift
//  Core
//
//  Created by zigdanis on 27/10/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//
//

import Foundation
import CoreData

@objc(AccessToWidget)
public class AccessToWidget: NSManagedObject {

}

extension AccessToWidget {

	@nonobjc
	public class func fetchRequest() -> NSFetchRequest<AccessToWidget> {
		return NSFetchRequest<AccessToWidget>(entityName: "AccessToWidget")
	}

	@NSManaged public var widgetPersons: Set<CoreDataPerson>?

	public class func sharedInstance(in context: NSManagedObjectContext) throws -> AccessToWidget {
		let fetch: NSFetchRequest<AccessToWidget> = fetchRequest()
		var shared: AccessToWidget?
		var coreError: CoreError?
		context.performAndWait {
			do {
				if let fetched = try context.fetch(fetch).first {
					shared = fetched
				} else {
					shared = context.addEntity(withType: AccessToWidget.self)
				}
			} catch {
				coreError = CoreError(error: error)
			}
		}
		if let error = coreError {
			throw error
		}
		guard let nonOptionalShared = shared else {
			throw CoreError.missingValue
		}
		return nonOptionalShared
	}
}

// MARK: Generated accessors for persons
extension AccessToWidget {

	@objc(addPersonsObject:)
	@NSManaged public func addToWidgetPersons(_ value: CoreDataPerson)

	@objc(removePersonsObject:)
	@NSManaged public func removeFromWidgetPersons(_ value: CoreDataPerson)

	@objc(addPersons:)
	@NSManaged public func addToWidgetPersons(_ values: NSSet)

	@objc(removePersons:)
	@NSManaged public func removeFromWidgetPersons(_ values: NSSet)

}
