//
//  Constants.swift
//  GrowingUp
//
//  Created by zigdanis on 22/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

public enum Constants {
	public static let bundleIdentifier = "pro.ziganshin.Core"
	public static let appGroupId = "group.pro.ziganshin.aging"
	public static let widgetBundle = "pro.ziganshin.GrowingUp.Widget"
	public static let widgetPeopleLimit = 6
	public static let widgetPersonIDKey = "personID"
	public static let widgetPersonIndexKey = "personIndex"
	/// The host of the `growingup-app://add-person` link that widgets open when nobody is pinned.
	public static let widgetAddPersonHost = "add-person"
	public static let openPersonNotification = Notification.Name(rawValue: "pro.ziganshin.GrowingUp.openPersonWithIndex")
}
