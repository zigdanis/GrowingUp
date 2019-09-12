//
//  ToggleCellViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 08/09/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

final class ToggleCellViewSpy: ToggleCellView {

	var displayedTitle: String?
	var displayedValue: Bool?
	weak var providedPresenter: ToggleCellPresenter?
	var providedRow: Int?

	func display(title: String) {
		displayedTitle = title
	}

	func display(isOn: Bool, animated: Bool) {
		displayedValue = isOn
	}

	func setup(with presenter: ToggleCellPresenter?, forRow row: Int) {
		providedPresenter = presenter
		providedRow = row
	}
}
