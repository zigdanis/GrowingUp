//
//  LabelCellViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

final class DateCellViewSpy: DateCellView {

	var displayedTitle: String?
	var displayedValue: String?

	func display(title: String) {
		displayedTitle = title
	}

	func display(value: String) {
		displayedValue = value
	}

}
