//
//  AddPersonParameters.swift
//  GrowingUp
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

struct AddPersonParameters: Equatable {
	var name: String
	var dayOfBirth: Date
	var timeOfBirth: Date
	var dateComponenets: AddPersonDateComponents
	var appImage: PersonImage?
	var widgetImage: PersonImage?
}

struct AddPersonDateComponents: Equatable {
	var years = true
	var months = true
	var days = true
	var hours = true
	var minutes = true
	var seconds = true
}

extension AddPersonParameters {

	func dateComponents() -> DateComponents {
		var components = DateComponents()
		let yearMonthDay = Calendar.current.dateComponents([.year, .month, .day], from: dayOfBirth)
		let hourMinuteSecond = Calendar.current.dateComponents([.year, .month, .day], from: timeOfBirth)
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
