//
//  TextFieldObserver.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

final class TextFieldObserverSpy: TextFieldObserver {

	var didChangeText: String?

	func textDidChange(forView: TextFieldCellView, text: String) {
		didChangeText = text
	}
}
