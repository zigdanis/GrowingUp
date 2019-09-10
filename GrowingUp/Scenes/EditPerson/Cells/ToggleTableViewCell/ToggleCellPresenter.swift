//
//  ToggleCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 28/06/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol ToggleCellPresenter: class {
	func configure(cell: ToggleCellView, forRow row: Int)
	func valueFor(row: Int, didChangeTo value: Bool)
	func valueFor(row: Int) -> Bool
}

final class ToggleCellPresenterImplementation: ToggleCellPresenter {
	private var storage = [Int: Bool]()

	func configure(cell: ToggleCellView, forRow row: Int) {
		cell.setup(with: self, forRow: row)
		cell.display(title: R.string.localizable.addToWidget())
		guard let value = storage[row] else { return }
		cell.display(isOn: value)
	}

	func valueFor(row: Int, didChangeTo value: Bool) {
		storage[row] = value
	}

	func valueFor(row: Int) -> Bool {
		return storage[row] ?? false
	}
}
