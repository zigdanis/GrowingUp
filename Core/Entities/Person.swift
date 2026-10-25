//
//  Person.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

public struct Person: Equatable, Hashable, Sendable {

	public var id: UUID
	public var name: String
	public var birthday: Date
	public var appPicId: UUID?
	public var widgetPicId: UUID?
	public var isOnWidget: Bool
	public var createdDate: Date
	/// Whether the overview celebrates this person's birthday with confetti.
	public var celebratesBirthdays: Bool
	/// The person's place in the mosaic, set by reordering; people never reordered share 0 and follow `createdDate`.
	public var displayOrder: Int

	public init(
		id: UUID,
		name: String,
		birthday: Date,
		appPicId: UUID?,
		widgetPicId: UUID?,
		isOnWidget: Bool,
		createdDate: Date,
		celebratesBirthdays: Bool = true,
		displayOrder: Int = 0
	) {
		self.id = id
		self.name = name
		self.birthday = birthday
		self.appPicId = appPicId
		self.widgetPicId = widgetPicId
		self.isOnWidget = isOnWidget
		self.createdDate = createdDate
		self.celebratesBirthdays = celebratesBirthdays
		self.displayOrder = displayOrder
	}

	public var dateComponents: DateComponents {
		return dateComponents(at: Date())
	}

	/// Age, broken into time components, computed from `birthday` up to `date`.
	/// Used by the widget to render age at each timeline entry's date.
	public func dateComponents(at date: Date) -> DateComponents {
		return AgeCalculator.ageComponents(from: birthday, to: date)
	}

	public var dayOfBirth: Date {
		let dayComponents = Calendar.current.dateComponents([.year, .month, .day], from: birthday)
		return Calendar.current.date(from: dayComponents) ?? Date()
	}

	public var timeOfBirth: Date {
		let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: birthday)
		return Calendar.current.date(from: timeComponents) ?? Date()
	}

}

/// The mosaic order, shared by the viewer's pages and the widgets: by `displayOrder`, then by `createdDate`.
extension Person: Comparable {

	public static func < (lhs: Person, rhs: Person) -> Bool {
		(lhs.displayOrder, lhs.createdDate) < (rhs.displayOrder, rhs.createdDate)
	}
}
