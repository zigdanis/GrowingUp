//
//  Person.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

struct Person: Equatable, Hashable {
	var id: UUID
    var name: String
    var birthday: Date
	var appPicId: UUID?
	var widgetPicId: UUID?

	var dateComponents: DateComponents {
		let then = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: birthday)
		let now = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
		return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: then, to: now)
	}

	var dayOfBirth: Date {
		let dayComponents = Calendar.current.dateComponents([.year, .month, .day], from: birthday)
		return Calendar.current.date(from: dayComponents) ?? Date()
	}

	var timeOfBirth: Date {
		let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: birthday)
		return Calendar.current.date(from: timeComponents) ?? Date()
	}
}
