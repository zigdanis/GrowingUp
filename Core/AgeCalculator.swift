//
//  AgeCalculator.swift
//  Core
//
//  Created by zigdanis on 15/12/2018.
//  Copyright © 2018 zigdanis. All rights reserved.
//

import Foundation

public enum AgeCalculator {

	public static func ageComponents() -> DateComponents {
		let initial = DateComponents(year: 2018, month: 10, day: 20, hour: 15, minute: 25, second: 0)
		let now = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
		return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: initial, to: now)
	}

	/// Age, broken into time components, from `birthday` up to `date`.
	public static func ageComponents(from birthday: Date, to date: Date) -> DateComponents {
		let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
		let then = Calendar.current.dateComponents(fields, from: birthday)
		let now = Calendar.current.dateComponents(fields, from: date)
		return Calendar.current.dateComponents(fields, from: then, to: now)
	}

	public static func ageString(for comps: DateComponents) -> String {

		let years = comps.year ?? 0
		let months = comps.month ?? 0
		let days = comps.day ?? 0
		let hours = comps.hour ?? 0
		let minutes = comps.minute ?? 0
		let seconds = comps.second ?? 0

		guard let bundle = Bundle(identifier: Constants.bundleIdentifier) else { return "" }
		var result = ""
		if years > 0 {
			result += " " + String(format: NSLocalizedString("%li years", bundle: bundle, comment: "Years"), years)
		}
		if months > 0 {
			result += " " + String(format: NSLocalizedString("%li months", bundle: bundle, comment: "Months"), months)
		}
		if days > 0 {
			result += " " + String(format: NSLocalizedString("%li days", bundle: bundle, comment: "Days"), days)
		}
		if hours > 0 {
			result += " " + String(format: NSLocalizedString("%li hours", bundle: bundle, comment: "Hour"), hours)
		}
		if minutes > 0 {
			result += " " + String(format: NSLocalizedString("%li minutes", bundle: bundle, comment: "Minutes"), minutes)
		}
		if seconds > 0 {
			result += " " + String(format: NSLocalizedString("%li seconds", bundle: bundle, comment: "Seconds"), seconds)
		}

		return result.trimmingCharacters(in: .whitespaces)
	}

}
