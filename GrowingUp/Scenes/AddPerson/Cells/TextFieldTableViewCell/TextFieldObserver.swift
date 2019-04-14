//
//  TextFieldObserver.swift
//  GrowingUp
//
//  Created by zigdanis on 14/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol TextFieldObserver: class {
	func textDidChange(forView: TextFieldCellView, text: String)
}

final class TextFieldObserverImplementation: TextFieldObserver {

	func textDidChange(forView: TextFieldCellView, text: String) {

	}
}
