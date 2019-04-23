//
//  Logging.swift
//  GrowingUp
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public enum Logging {
	public static func log(_ error: CoreError) {
		print("Error with title = \(error.title)\nMessage = \(error.message)")
	}
}
