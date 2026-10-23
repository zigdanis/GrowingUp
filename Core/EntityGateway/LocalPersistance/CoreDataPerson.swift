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
	/// The birth moment saved before `floatingBirthdate` existed; only read once to pin it.
	@NSManaged public var birthdate: Date?
	/// `Person.floatingBirthdate`; `nil` only until a store saved by an earlier version pins its legacy `birthdate`.
	@NSManaged public var floatingBirthdate: Date?
	@NSManaged public var id: String?
	@NSManaged public var name: String?
	@NSManaged public var widgetPicId: String?
	@NSManaged public var createdDate: Date
	@NSManaged public var celebratesBirthdays: Bool
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
			floatingBirthdate: floatingBirthdate ?? pinnedLegacyBirthdate,
			appPicId: UUID(string: appPicId),
			widgetPicId: UUID(string: widgetPicId),
			isOnWidget: isOnWidget,
			createdDate: createdDate,
			celebratesBirthdays: celebratesBirthdays)
	}

	/// The legacy `birthdate` as the date and time it shows in the current time zone.
	private var pinnedLegacyBirthdate: Date {
		Person.floatingBirthdate(of: birthdate ?? createdDate)
	}

	/// Gives every person saved before birthdates were floating the date and time their birthday shows now, so the
	/// day stays the same after the device changes time zone.
	static func pinLegacyBirthdates(in context: NSManagedObjectContext) throws {
		let request = fetchRequest()
		request.predicate = NSPredicate(format: "floatingBirthdate == nil")
		for person in try context.fetch(request) {
			person.floatingBirthdate = person.pinnedLegacyBirthdate
		}
		if context.hasChanges { try context.save() }
	}

	public func populate(with parameters: AddPersonParameters) {
		name = parameters.name
		let birthday = parameters.combinedDate()
		// An unchanged birthday keeps its stored reading, which the local clock cannot always show back, such as a birth
		// at 01:00 on a day that starts at 01:00 after daylight saving time skipped midnight.
		if floatingBirthdate == nil || person.birthday != birthday {
			floatingBirthdate = Person.floatingBirthdate(of: birthday)
		}
		appPicId = parameters.appImage?.id.uuidString
		widgetPicId = parameters.widgetImage?.id.uuidString
		celebratesBirthdays = parameters.celebratesBirthdays
	}

}
