//
//  SwitchCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 19/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol SwitchCellPresenter {
	func configure(cell: SwitchCellView, forRow row: Int)
	var valuesForRow: [Int: Bool] { get set }
	func updatedComponents() -> AddPersonDateComponents
}

protocol SwitchCellDelegate: class {
	func modelValue(forRow row: Int, didUpdateTo value: Bool)
}

final class SwitchCellPresenterImplementation: SwitchCellPresenter {
	
	var valuesForRow = [Int: Bool]()
	
	func configure(cell: SwitchCellView, forRow row: Int) {
		switch row {
		case 3:
			cell.display(title: R.string.localizable.showYears())
		case 4:
			cell.display(title: R.string.localizable.showMonths())
		case 5:
			cell.display(title: R.string.localizable.showDays())
		case 6:
			cell.display(title: R.string.localizable.showHours())
		case 7:
			cell.display(title: R.string.localizable.showMinutes())
		case 8:
			cell.display(title: R.string.localizable.showSeconds())
		default:
			assertionFailure("We support SwitchCellView only for rows in [3...8]")
		}
		guard let value = valuesForRow[row] else { return }
		cell.setSwitch(isOn: value)
	}
	
	func updatedComponents() -> AddPersonDateComponents {
		var components = AddPersonDateComponents()
		for (key, value) in valuesForRow {
			switch key {
			case 3: components.years = value
			case 4: components.months = value
			case 5: components.days = value
			case 6: components.hours = value
			case 7: components.minutes = value
			case 8: components.seconds = value
			default:
				assertionFailure("We support SwitchCellView only for rows in [3...8]")
			}
		}
		return components
	}
	
}

extension SwitchCellPresenterImplementation: SwitchCellDelegate {
	
	func modelValue(forRow row: Int, didUpdateTo value: Bool) {
		valuesForRow[row] = value
	}
}
