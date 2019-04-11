//
//  TextFieldCellPresenterSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

final class TextFieldCellPresenterStub: TextFieldCellPresenter {

	var didCallConfigure = false
	private var storage = [Int: String]()

	func configure(cell: TextFieldCellView, forRow row: Int) {
		didCallConfigure = true
	}

	func valueFor(row: Int, didChangeTo value: String) {
		storage[row] = value
	}

	func valueFor(row: Int) -> String? {
		return storage[row]
	}

}
