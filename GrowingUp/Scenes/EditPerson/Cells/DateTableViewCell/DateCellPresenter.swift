//
//  DateCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 19/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol DateCellPresenter: AnyObject {
	func configure(cell: DateCellView, forRow row: Int)
	func valueFor(row: Int, didChangeTo value: Date)
	func valueFor(row: Int) -> Date?
}

final class DateCellPresenterImplementation: DateCellPresenter {

	private var storage = [Int: Date]()
	weak var dateDelegate: DateCellDelegate?

	func configure(cell: DateCellView, forRow row: Int) {
		cell.setup(with: dateDelegate, forRow: row)
		cell.display(title: R.string.localizable.birthday())
		cell.display(date: combinedBirthday)
	}

	func valueFor(row: Int, didChangeTo value: Date) {
		storage[row] = value
	}

	func valueFor(row: Int) -> Date? {
		return storage[row]
	}

	/// The single birthday shown by the combined date+time picker, rebuilt from the
	/// separate day and time slots that the rest of the flow (and Core) still expect.
	private var combinedBirthday: Date? {
		guard let day = storage[EPC.dayPickerRow] else { return storage[EPC.timePickerRow] }
		guard let time = storage[EPC.timePickerRow] else { return day }
		let calendar = Calendar.current
		var components = calendar.dateComponents([.year, .month, .day], from: day)
		let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
		components.hour = timeComponents.hour
		components.minute = timeComponents.minute
		components.second = timeComponents.second
		return calendar.date(from: components) ?? day
	}
}
