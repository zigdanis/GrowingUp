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
	/// The date and clock time of birth written as UTC, so it means the same reading on every local clock.
	///
	/// A birthday therefore stays on its calendar day wherever the device travels. An unknown birth time is midnight.
	public var floatingBirthdate: Date
	public var appPicId: UUID?
	public var widgetPicId: UUID?
	public var isOnWidget: Bool
	public var createdDate: Date
	/// Whether the overview celebrates this person's birthday with confetti.
	public var celebratesBirthdays: Bool

	public init(
		id: UUID,
		name: String,
		floatingBirthdate: Date,
		appPicId: UUID?,
		widgetPicId: UUID?,
		isOnWidget: Bool,
		createdDate: Date,
		celebratesBirthdays: Bool = true
	) {
		self.id = id
		self.name = name
		self.floatingBirthdate = floatingBirthdate
		self.appPicId = appPicId
		self.widgetPicId = widgetPicId
		self.isOnWidget = isOnWidget
		self.createdDate = createdDate
		self.celebratesBirthdays = celebratesBirthdays
	}

	/// The moment the local clock shows `floatingBirthdate`, used for display and age in the current time zone.
	public var birthday: Date {
		get { Self.clockReading(of: floatingBirthdate, in: .gmt, shownIn: Calendar.current.timeZone) }
		set { floatingBirthdate = Self.floatingBirthdate(of: newValue) }
	}

	/// The floating birthdate that reads in UTC as the local `birthday` reads in the current time zone.
	public static func floatingBirthdate(of birthday: Date) -> Date {
		clockReading(of: birthday, in: Calendar.current.timeZone, shownIn: .gmt)
	}

	/// The moment a clock in `target` shows the date and time that a clock in `source` shows at `date`.
	///
	/// The start of a day stays the start of a day, even where daylight saving time skips midnight and the day starts at 01:00.
	private static func clockReading(of date: Date, in source: TimeZone, shownIn target: TimeZone) -> Date {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = source
		let isStartOfDay = date == calendar.startOfDay(for: date)
		let reading = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
		calendar.timeZone = target
		guard let moved = calendar.date(from: reading) else { return date }
		return isStartOfDay ? calendar.startOfDay(for: moved) : moved
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

extension Person: Comparable {

	public static func < (lhs: Person, rhs: Person) -> Bool {
		let comparison = lhs.createdDate.compare(rhs.createdDate)
		return comparison == .orderedAscending
	}
}
