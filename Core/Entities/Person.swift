//
//  Person.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public struct Person: Equatable, Hashable {

	public var id: UUID
    public var name: String
    public var birthday: Date
	public var appPicId: UUID?
	public var widgetPicId: UUID?
	public var isOnWidget: Bool
	public var order: Int

	public init(id: UUID,
				name: String,
				birthday: Date,
				appPicId: UUID?,
				widgetPicId: UUID?,
				isOnWidget: Bool,
				order: Int) {
		self.id = id
		self.name = name
		self.birthday = birthday
		self.appPicId = appPicId
		self.widgetPicId = widgetPicId
		self.isOnWidget = isOnWidget
		self.order = order
	}

	public var dateComponents: DateComponents {
		let then = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: birthday)
		let now = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
		return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: then, to: now)
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
