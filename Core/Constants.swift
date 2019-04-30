//
//  Constants.swift
//  GrowingUp
//
//  Created by zigdanis on 22/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public enum Constants {
	public static let bundleIdentifier = "pro.ziganshin.Core"
	public static let appGroupId = "group.pro.ziganshin.aging"
	public static let widgetBundle = "pro.ziganshin.GrowingUp.Widget"
	public static let widgetPersonIndexKey = "personIndex"
	public static let openPersonNotification = Notification.Name(rawValue: "pro.ziganshin.GrowingUp.openPersonWithIndex")

//	static let swiftyBearAppId = "bJPXa3"
//	static let swiftyBearAppSecret = "q0fxlcfjfoajqbjpw2wlrwfc6gvunh5k"
//	static let swiftyBearEncryption = "rteZzjbjHucLtxjeiaicf8nfcLkEra6e"
//	static let mixpanelToken = "cf19da2125b5c9625a5de1f21696f45b"
	public static let obfusSBAppId: [UInt8] = [54, 43, 35, 51, 44, 82]
	public static let obfusSBAppSecret: [UInt8] = [37, 81, 21, 19, 33, 2, 8, 11, 1, 10, 19, 36, 34, 45, 8, 26, 18, 81, 3, 56, 19, 4, 13, 46, 87, 9, 23, 18, 11, 26, 123, 56]
	public static let obfusSBEncryption: [UInt8] = [38, 21, 22, 49, 55, 11, 12, 11, 47, 16, 17, 2, 39, 55, 8, 15, 12, 2, 29, 55, 7, 75, 5, 43, 2, 34, 10, 34, 23, 19, 120, 54]
	public static let obfusMPToken: [UInt8] = [55, 7, 66, 82, 41, 0, 92, 80, 85, 80, 16, 123, 48, 118, 84, 88, 80, 2, 65, 48, 4, 66, 13, 127, 80, 88, 88, 81, 3, 70, 123, 49]
}
