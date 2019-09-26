//
//  Logging.swift
//  GrowingUp
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public enum Logging {

	public static func setup() {
//		let console = ConsoleDestination()
//		let file = FileDestination()
//		let obfuscator = Obfuscator()
//		let appId = obfuscator.reveal(key: Constants.obfusSBAppId)
//		let appSecretId = obfuscator.reveal(key: Constants.obfusSBAppSecret)
//		let encryption = obfuscator.reveal(key: Constants.obfusSBEncryption)
//		let platform = SBPlatformDestination(appID: appId, appSecret: appSecretId, encryptionKey: encryption)
//		#if DEBUG
//		file.logFileURL = URL(fileURLWithPath: "/tmp/swiftybeaver.log")
//		#endif
//		SwiftyBeaver.addDestination(console)
//		SwiftyBeaver.addDestination(file)
//		SwiftyBeaver.addDestination(platform)
//
//		Mixpanel.sharedInstance(withToken: obfuscator.reveal(key: Constants.obfusMPToken))
	}

	public static func logError(_ error: CoreError) {
		let value = "❌ \(error.title)\n\(error.message)"
	}

	public static func logMessage(_ message: String, params: [String: String]? = nil) {
		let value = "✍️ \(message)"
	}

	public static func logWarning(_ warning: String) {
		let value = "⚠️ \(warning)"
	}
}
