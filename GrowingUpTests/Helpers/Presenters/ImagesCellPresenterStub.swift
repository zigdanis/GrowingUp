//
//  ImagePickersCellPresenterStub.swift
//  GrowingUpTests
//
//  Created by zigdanis on 23/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

class ImagesCellPresenterStub: ImagesCellPresenter {

	private var storage = [Int: PersonPics]()

	func configure(cell: ImagesCellView, forRow row: Int, with delegate: ImagesCellViewDelegate) {
		cell.setup(with: delegate, forRow: row)
	}

	func valueFor(row: Int, didChangeTo value: PersonPics) {
		storage[row] = value
	}

	func valueFor(row: Int) -> PersonPics? {
		return storage[row]
	}
}
