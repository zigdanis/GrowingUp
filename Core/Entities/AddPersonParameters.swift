//
//  AddPersonParameters.swift
//  GrowingUp
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public struct AddPersonParameters: Equatable {
	public var name: String
	public var dayOfBirth: Date
	public var timeOfBirth: Date
	public var dateComponennts: AddPersonDateComponents
	public var appImage: PersonImage?
	public var widgetImage: PersonImage?

	public init(name: String,
				dayOfBirth: Date,
				timeOfBirth: Date,
				dateComponents: AddPersonDateComponents,
				appImage: PersonImage?,
				widgetImage: PersonImage?) {
		self.name = name
		self.dayOfBirth = dayOfBirth
		self.timeOfBirth = timeOfBirth
		self.dateComponennts = dateComponents
		self.appImage = appImage
		self.widgetImage = widgetImage
	}
}

public struct AddPersonDateComponents: Equatable {
	public var years = true
	public var months = true
	public var days = true
	public var hours = true
	public var minutes = true
	public var seconds = true

	public init() {}
}

public extension AddPersonParameters {

	func dateComponents() -> DateComponents {
		var components = DateComponents()
		let yearMonthDay = Calendar.current.dateComponents([.year, .month, .day], from: dayOfBirth)
		let hourMinuteSecond = Calendar.current.dateComponents([.hour, .minute, .second], from: timeOfBirth)
		components.setValue(yearMonthDay.year, for: .year)
		components.setValue(yearMonthDay.month, for: .month)
		components.setValue(yearMonthDay.day, for: .day)
		components.setValue(hourMinuteSecond.hour, for: .hour)
		components.setValue(hourMinuteSecond.minute, for: .minute)
		components.setValue(hourMinuteSecond.second, for: .second)
		return components
	}

	func combinedDate() -> Date? {
		let components = dateComponents()
		return Calendar.current.date(from: components)
	}
}
