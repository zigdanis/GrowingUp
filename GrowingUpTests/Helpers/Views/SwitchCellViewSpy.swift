//
//  SwitchCellViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

final class SwitchCellViewSpy: SwitchCellView {
	var displayedTitle: String?
	var displayedStatus: Bool?

	func display(title: String) {
		displayedTitle = title
	}

	func setSwitch(isOn: Bool) {
		displayedStatus = isOn
	}

	func setup(with presenter: SwitchCellPresenter, forRow row: Int) {

	}

}
