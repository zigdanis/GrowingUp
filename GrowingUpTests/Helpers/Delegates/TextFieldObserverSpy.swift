//
//  TextFieldObserver.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@testable import Core
@testable import GrowingUp

final class TextFieldObserverSpy: TextFieldObserver {

	var didChangeText: String?

	func textDidChange(forView: TextFieldCellView, text: String) {
		didChangeText = text
	}
}
