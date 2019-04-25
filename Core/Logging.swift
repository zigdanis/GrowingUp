//
//  Logging.swift
//  GrowingUp
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import SwiftyBeaver

let log = SwiftyBeaver.self

public enum Logging {

	public static func setup() {
		let console = ConsoleDestination()
		let file = FileDestination()
		#if DEBUG
		file.logFileURL = URL(fileURLWithPath: "/tmp/swiftybeaver.log")
		#endif
		log.addDestination(console)
		log.addDestination(file)
	}

	public static func logError(_ error: CoreError) {
		log.error("❌ \(error.title)\n\(error.message)")
	}

	public static func logMessage(_ message: String) {
		log.debug("✍️ \(message)")
	}
}
