//
//  Obfuscator.swift
//  Core
//
//  Created by zigdanis on 26/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

class Obfuscator {

	// MARK: - Variables

	/// The salt used to obfuscate and reveal the string.
	private var salt: String

	// MARK: - Initialization

	init() {
		self.salt = "\(String(describing: TaskManager.self))\(String(describing: NSObject.self))"
	}

	init(with salt: String) {
		self.salt = salt
	}

	// MARK: - Instance Methods

	/**
	This method obfuscates the string passed in using the salt
	that was used when the Obfuscator was initialized.

	- parameter string: the string to obfuscate

	- returns: the obfuscated string in a byte array
	*/
	func bytesByObfuscatingString(string: String) -> [UInt8] {
		let text = [UInt8](string.utf8)
		let cipher = [UInt8](self.salt.utf8)
		let length = cipher.count

		var encrypted = [UInt8]()

		for textChunk in text.enumerated() {
			encrypted.append(textChunk.element ^ cipher[textChunk.offset % length])
		}

		#if DEVELOPMENT
		print("Salt used: \(self.salt)\n")
		print("Swift Code:\n************")
		print("// Original \"\(string)\"")
		print("let key: [UInt8] = \(encrypted)\n")
		#endif

		return encrypted
	}

	/**
	This method reveals the original string from the obfuscated
	byte array passed in. The salt must be the same as the one
	used to encrypt it in the first place.

	- parameter key: the byte array to reveal

	- returns: the original string
	*/
	func reveal(key: [UInt8]) -> String {
		let cipher = [UInt8](self.salt.utf8)
		let length = cipher.count

		var decrypted = [UInt8]()

		for nextKey in key.enumerated() {
			decrypted.append(nextKey.element ^ cipher[nextKey.offset % length])
		}

		return String(bytes: decrypted, encoding: .utf8)!
	}
}
