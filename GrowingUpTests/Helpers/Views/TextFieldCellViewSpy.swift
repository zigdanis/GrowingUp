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
	
	
	func display(title: String) {
		displayedTitle = title
	}
	
	func display(value: String) {
		displayedValue = value
	}
	
	func display(placeholder: String) {
		displayedPlaceholder = placeholder
	}
	
	func setup(with delegate: TextFieldCellViewDelegate, forRow row: Int) {
		
	}
}
