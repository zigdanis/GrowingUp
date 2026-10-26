//
//  CoreDataPerson.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
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
	@NSManaged public var originalPicId: String?
	/// `PhotoCrop.storedValue` of the main picture's region of the original.
	@NSManaged public var appPicCrop: String?
	/// `PhotoCrop.storedValue` of the widget picture's region of the original.
	@NSManaged public var widgetPicCrop: String?
	@NSManaged public var createdDate: Date
	@NSManaged public var celebratesBirthdays: Bool
	@NSManaged public var displayOrder: Int64
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
			createdDate: createdDate,
			celebratesBirthdays: celebratesBirthdays,
			displayOrder: Int(displayOrder),
			originalPicId: UUID(string: originalPicId),
			appPicCrop: PhotoCrop(storedValue: appPicCrop),
			widgetPicCrop: PhotoCrop(storedValue: widgetPicCrop))
	}

	public func populate(with parameters: AddPersonParameters) {
		name = parameters.name
		birthdate = parameters.combinedDate()
		appPicId = parameters.appImage?.id.uuidString
		widgetPicId = parameters.widgetImage?.id.uuidString
		originalPicId = parameters.originalImage?.id.uuidString
		appPicCrop = parameters.appImage?.crop?.storedValue
		widgetPicCrop = parameters.widgetImage?.crop?.storedValue
		celebratesBirthdays = parameters.celebratesBirthdays
	}

}
