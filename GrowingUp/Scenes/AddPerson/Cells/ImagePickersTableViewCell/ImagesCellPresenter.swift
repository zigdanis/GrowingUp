//
//  ImagePickersCellPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 23/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol ImagesCellPresenter: class {
	func configure(cell: ImagesCellView, forRow row: Int, with delegate: ImagesCellViewDelegate)
	func valueFor(row: Int, didChangeTo value: PersonPics)
	func valueFor(row: Int) -> PersonPics?
}

class ImagesCellPresenterImplementation: ImagesCellPresenter {

	private var storage = [Int: PersonPics]()

	func configure(cell: ImagesCellView, forRow row: Int, with delegate: ImagesCellViewDelegate) {
		let pics = storage[row]
		cell.display(appPic: pics?.appPic)
		cell.display(widgetPic: pics?.widgetPic)
		cell.setup(with: delegate, forRow: row)
	}

	func valueFor(row: Int, didChangeTo value: PersonPics) {
		storage[row] = value
	}

	func valueFor(row: Int) -> PersonPics? {
		return storage[row]
	}

}
