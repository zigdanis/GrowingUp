//
//  LabelCellPresenterSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

final class DateCellPresenterStub: DateCellPresenter {

	var storage = [Int: Date]()

	func valueFor(row: Int, didChangeTo value: Date) {
		storage[row] = value
	}

	func valueFor(row: Int) -> Date? {
		return storage[row]
	}

	func configure(cell: DateCellView, forRow row: Int) {

	}

}
