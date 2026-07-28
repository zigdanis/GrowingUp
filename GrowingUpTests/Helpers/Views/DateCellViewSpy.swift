//
//  DateCellViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@testable import Core
@testable import GrowingUp

final class DateCellViewSpy: DateCellView {

	var displayedTitle: String?
	var displayedDate: Date?
	var didCallSetup = false

	func display(title: String) {
		displayedTitle = title
	}

	func display(date: Date?) {
		displayedDate = date
	}

	func setup(with delegate: DateCellDelegate?, forRow row: Int) {
		didCallSetup = true
	}

}
