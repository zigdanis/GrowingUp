//
//  ToggleCellViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 08/09/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@testable import Core
@testable import GrowingUp

final class ToggleCellViewSpy: ToggleCellView {

	var displayedTitle: String?
	var displayedValue: Bool?
	weak var providedDelegate: ToggleCellDelegate?
	var providedRow: Int?

	func display(title: String) {
		displayedTitle = title
	}

	func display(isOn: Bool, animated: Bool) {
		displayedValue = isOn
	}

	func setup(with delegate: ToggleCellDelegate?, forRow row: Int) {
		providedDelegate = delegate
		providedRow = row
	}
}
