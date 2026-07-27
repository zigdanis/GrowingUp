//
//  CoreDataPerson.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import CoreData
import Foundation

@objc(CoreDataPerson)
public class CoreDataPerson: NSManagedObject {
	@NSManaged public var appPicId: String?
	@NSManaged public var birthdate: Date
	@NSManaged public var id: String?
	@NSManaged public var name: String?
	@NSManaged public var widgetPicId: String?
	@NSManaged public var createdDate: Date
	@NSManaged public var accessToWidget: AccessToWidget?
}

extension CoreDataPerson {

	public var isOnWidget: Bool {
		return accessToWidget != nil
	}

	public override func awakeFromInsert() {
		super.awakeFromInsert()
		self.createdDate = Date()
		self.id = UUID().uuidString
	}

	@nonobjc
	public class func fetchRequest() -> NSFetchRequest<CoreDataPerson> {
		return NSFetchRequest<CoreDataPerson>(entityName: "CoreDataPerson")
	}

	public var person: Person {
		return Person(
			id: UUID(string: id) ?? UUID(),
			name: name ?? "",
			birthday: birthdate,
			appPicId: UUID(string: appPicId),
			widgetPicId: UUID(string: widgetPicId),
			isOnWidget: isOnWidget,
			createdDate: createdDate)
	}

	public func populate(with parameters: AddPersonParameters) {
		name = parameters.name
		birthdate = parameters.combinedDate()
		appPicId = parameters.appImage?.id.uuidString
		widgetPicId = parameters.widgetImage?.id.uuidString
	}

}
