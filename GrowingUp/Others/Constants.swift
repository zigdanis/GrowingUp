//
//  Constants.swift
//  GrowingUp
//
//  Created by zigdanis on 22/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

enum Constants {
	static let appGroupId = "group.pro.ziganshin.aging"
	static let widgetBundle = "pro.ziganshin.GrowingUp.Widget"
	static let widgetPersonIndexKey = "personIndex"
	static let openPersonNotification = Notification.Name(rawValue: "pro.ziganshin.GrowingUp.openPersonWithIndex")

//	static let swiftyBearAppId = "bJPXa3"
//	static let swiftyBearAppSecret = "q0fxlcfjfoajqbjpw2wlrwfc6gvunh5k"
//	static let swiftyBearEncryption = "rteZzjbjHucLtxjeiaicf8nfcLkEra6e"
	static let obfusSBAppId: [UInt8] = [54, 43, 35, 51, 44, 82]
	static let obfusSBAppSecret: [UInt8] = [37, 81, 21, 19, 33, 2, 8, 11, 1, 10, 19, 36, 34, 45, 8, 26, 18, 81, 3, 56, 19, 4, 13, 46, 87, 9, 23, 18, 11, 26, 123, 56]
	static let obfusSBEncryption: [UInt8] = [38, 21, 22, 49, 55, 11, 12, 11, 47, 16, 17, 2, 39, 55, 8, 15, 12, 2, 29, 55, 7, 75, 5, 43, 2, 34, 10, 34, 23, 19, 120, 54]
}
