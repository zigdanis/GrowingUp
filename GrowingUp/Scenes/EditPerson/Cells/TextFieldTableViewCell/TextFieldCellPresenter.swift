//
//  TextFieldCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 19/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol TextFieldCellPresenter: AnyObject {
	func configure(cell: TextFieldCellView, forRow row: Int)
	func valueFor(row: Int, didChangeTo value: String)
	func valueFor(row: Int) -> String?
}

final class TextFieldCellPresenterImplementation: TextFieldCellPresenter {

	private var storage = [Int: String]()
	weak var textFieldObserver: TextFieldObserver?

	func configure(cell: TextFieldCellView, forRow row: Int) {
		cell.setup(with: self, observer: textFieldObserver, forRow: row)
		cell.display(title: R.string.localizable.name())
		cell.display(placeholder: R.string.localizable.name())
		guard let value = storage[row] else { return }
		cell.display(value: value)
	}

	func valueFor(row: Int, didChangeTo value: String) {
		storage[row] = value
	}

	func valueFor(row: Int) -> String? {
		return storage[row]?.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
