//
//  TextFieldCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 19/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol TextFieldCellPresenter {
	func configure(cell: TextFieldCellView, forRow row: Int)
	var valuesForRow: [Int: String] { get set }
}

protocol TextFieldCellViewDelegate: class {
	func modelValue(forRow row: Int, didUpdateTo value: String)
}

final class TextFieldCellPresenterImplementation: TextFieldCellPresenter {
	
	var valuesForRow = [Int: String]()
	
	func configure(cell: TextFieldCellView, forRow row: Int) {
		cell.setup(with: self, forRow: row)
		cell.display(title: R.string.localizable.name())
		cell.display(placeholder: R.string.localizable.name())
		guard let value = valuesForRow[row] else { return }
		cell.display(value: value)
	}
}

extension TextFieldCellPresenterImplementation: TextFieldCellViewDelegate {
	
	func modelValue(forRow row: Int, didUpdateTo value: String) {
		valuesForRow[row] = value
	}
	
}
