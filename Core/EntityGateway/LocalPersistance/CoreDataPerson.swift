//
//  CoreDataPerson.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import CoreData

@objc(CoreDataPerson)
public class CoreDataPerson: NSManagedObject {
	@NSManaged public var appPicId: String?
	@NSManaged public var birthdate: NSDate?
	@NSManaged public var id: String?
	@NSManaged public var name: String?
	@NSManaged public var widgetPicId: String?
	@NSManaged public var isOnWidget: Bool
}

extension CoreDataPerson {

    public var person: Person {
		return Person(id: UUID(string: id) ?? UUID(),
					  name: name ?? "",
					  birthday: birthdate as Date? ?? Date(),
					  appPicId: UUID(string: appPicId),
					  widgetPicId: UUID(string: widgetPicId))
    }

    public func populate(with parameters: AddPersonParameters) {
		if id == nil {
			id = UUID().uuidString
		}
        name = parameters.name
		birthdate = parameters.combinedDate() as NSDate?
		appPicId = parameters.appImage?.id.uuidString
		widgetPicId = parameters.widgetImage?.id.uuidString
    }

}
