//
//  DateCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 19/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol DateCellPresenter {
	func configure(cell: DateCellView, forRow row: Int)
	var valuesForRow: [Int: Date] { get set }
	func modelValue(forRow row: Int, didUpdateTo value: Date)
}

final class DateCellPresenterImplementation: DateCellPresenter {
	
	var valuesForRow = [Int: Date]()
	
	func configure(cell: DateCellView, forRow row: Int) {
		switch row {
		case 1:
			cell.display(title: R.string.localizable.dateOfBirth())
			let value = valuesForRow[row]?.dateString() ?? "xx.xx.xxxx"
			cell.display(value: value)
		case 2:
			cell.display(title: R.string.localizable.timeOfBirth())
			let value = valuesForRow[row]?.timeString() ?? "xx:xx"
			cell.display(value: value)
		default:
			assertionFailure("We support LabelCellView only for rows in [1...2]")
		}
	}
	
	func modelValue(forRow row: Int, didUpdateTo value: Date) {
		valuesForRow[row] = value
	}
}

