//
//  SwitchCellPresenterStub.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

final class SwitchCellPresenterStub: SwitchCellPresenter {

	private var storage = [Int: Bool]()
	var didCallConfigure = false

	func configure(cell: SwitchCellView, forRow row: Int) {
		didCallConfigure = true
	}

	func valueFor(row: Int, didChangeTo value: Bool) {
		storage[row] = value
	}

	func valueFor(row: Int) -> Bool? {
		return storage[row]
	}
	func updatedComponents() -> AddPersonDateComponents {
		return AddPersonDateComponents()
	}

}
