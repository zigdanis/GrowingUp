//
//  WDImageError.swift
//  GrowingUp
//
//  Created by zigdanis on 08/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

struct WDImageError: Error {

	var message = ""

	var localizedDescription: String {
		return message
	}

	init(message: String) {
		self.message = message
	}

	static let imageCropFailed = WDImageError(message: "Cropping image Failed")
	static let imageScaleFailed = WDImageError(message: "Scaling image Failed")
}
