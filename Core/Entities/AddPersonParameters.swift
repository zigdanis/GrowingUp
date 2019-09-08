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
	public var appImage: PersonImage?
	public var widgetImage: PersonImage?
	public var isOnWidget: Bool = false

	public init(name: String,
				dayOfBirth: Date,
				timeOfBirth: Date,
				appImage: PersonImage?,
				widgetImage: PersonImage?,
				isOnWidget: Bool = false) {
		self.name = name
		self.dayOfBirth = dayOfBirth
		self.timeOfBirth = timeOfBirth
		self.appImage = appImage
		self.widgetImage = widgetImage
		self.isOnWidget = isOnWidget
	}
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
