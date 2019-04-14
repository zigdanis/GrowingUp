//
//  TextFieldCellViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 19/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

@testable import GrowingUp

class TextFieldCellViewSpy: TextFieldCellView {

	var displayedTitle: String?
	var displayedValue: String?
	var displayedPlaceholder: String?
	var presenter: TextFieldCellPresenter?
	var observer: TextFieldObserver?
	var row: Int?

	func display(title: String) {
		displayedTitle = title
	}

	func display(value: String) {
		displayedValue = value
	}

	func display(placeholder: String) {
		displayedPlaceholder = placeholder
	}

	func setup(with presenter: TextFieldCellPresenter, observer: TextFieldObserver?, forRow row: Int) {
		self.presenter = presenter
		self.observer = observer
		self.row = row
	}
}
