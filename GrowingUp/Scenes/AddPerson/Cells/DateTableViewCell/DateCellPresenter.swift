//
//  DateCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 19/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol DateCellPresenter: class {
	func configure(cell: DateCellView, forRow row: Int)
	func valueFor(row: Int, didChangeTo value: Date)
	func valueFor(row: Int) -> Date?
}

final class DateCellPresenterImplementation: DateCellPresenter {
	
	private var storage = [Int: Date]()
	
	func configure(cell: DateCellView, forRow row: Int) {
		switch row {
		case 1:
			cell.display(title: R.string.localizable.dayOfBirth())
			let value = storage[row]?.dateString() ?? "xx.xx.xxxx"
			cell.display(value: value)
		case 2:
			cell.display(title: R.string.localizable.timeOfBirth())
			let value = storage[row]?.timeString() ?? "xx:xx"
			cell.display(value: value)
		default:
			assertionFailure("We support LabelCellView only for rows in [1...2]")
		}
	}
	
	func valueFor(row: Int, didChangeTo value: Date) {
		storage[row] = value
	}
	
	func valueFor(row: Int) -> Date? {
		return storage[row]
	}
}

