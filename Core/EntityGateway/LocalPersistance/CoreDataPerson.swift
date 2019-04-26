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
	@NSManaged public var appPicId: UUID?
	@NSManaged public var birthdate: NSDate?
	@NSManaged public var id: UUID?
	@NSManaged public var name: String?
	@NSManaged public var widgetPicId: UUID?
}

extension CoreDataPerson {

    public var person: Person {
		return Person(id: id ?? UUID(),
					  name: name ?? "",
					  birthday: birthdate as Date? ?? Date(),
					  appPicId: appPicId,
					  widgetPicId: widgetPicId)
    }

    public func populate(with parameters: AddPersonParameters) {
		if id == nil {
			id = UUID()
		}
        name = parameters.name
		birthdate = parameters.combinedDate() as NSDate?
		appPicId = parameters.appImage?.id
		widgetPicId = parameters.widgetImage?.id
    }

}
