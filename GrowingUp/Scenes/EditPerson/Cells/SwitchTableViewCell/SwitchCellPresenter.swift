//
//  SwitchCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 19/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol SwitchCellPresenter: class {
	func configure(cell: SwitchCellView, forRow row: Int)
	func valueFor(row: Int, didChangeTo value: Bool)
	func valueFor(row: Int) -> Bool?
	func updatedComponents() -> AddPersonDateComponents
}

final class SwitchCellPresenterImplementation: SwitchCellPresenter {

	private var storage = [Int: Bool]()

	func configure(cell: SwitchCellView, forRow row: Int) {
		let supportedRows = Array(EPC.dateComponentsRows)
		switch row {
		case supportedRows[0]:
			cell.display(title: R.string.localizable.showYears())
		case supportedRows[1]:
			cell.display(title: R.string.localizable.showMonths())
		case supportedRows[2]:
			cell.display(title: R.string.localizable.showDays())
		case supportedRows[3]:
			cell.display(title: R.string.localizable.showHours())
		case supportedRows[4]:
			cell.display(title: R.string.localizable.showMinutes())
		case supportedRows[5]:
			cell.display(title: R.string.localizable.showSeconds())
		default:
			assertionFailure("We support SwitchCellView only for rows in [3...8]")
		}
		guard let value = storage[row] else { return }
		cell.setSwitch(isOn: value)
	}

	func valueFor(row: Int, didChangeTo value: Bool) {
		storage[row] = value
	}

	func valueFor(row: Int) -> Bool? {
		return storage[row]
	}

	func updatedComponents() -> AddPersonDateComponents {
		var components = AddPersonDateComponents()
		let supportedRows = Array(EPC.dateComponentsRows)
		for (key, value) in storage {
			switch key {
			case supportedRows[0]: components.years = value
			case supportedRows[1]: components.months = value
			case supportedRows[2]: components.days = value
			case supportedRows[3]: components.hours = value
			case supportedRows[4]: components.minutes = value
			case supportedRows[5]: components.seconds = value
			default:
				assertionFailure("We support SwitchCellView only for rows in APC.dateComponentsRows")
			}
		}
		return components
	}

}
