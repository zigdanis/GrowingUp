//
//  Logging.swift
//  GrowingUp
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public enum Logging {
	public static func logError(_ error: CoreError) {
		print("❌ \(error.title)\n\(error.message)")
	}

	public static func logMessage(_ message: String) {
		print("✍️ \(message)")
	}
}
