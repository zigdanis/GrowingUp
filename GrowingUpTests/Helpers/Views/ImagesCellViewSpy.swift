//
//  ImagesCellViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 23/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit
@testable import GrowingUp

class ImagesCellViewSpy: ImagesCellView {

	var displayedAppPic: UIImage?
	var displayedWidgetPic: UIImage?
	weak var providedDelegate: ImagesCellViewDelegate?
	var providedRow: Int?

	func display(appPic: UIImage?) {
		displayedAppPic = appPic
	}

	func display(widgetPic: UIImage?) {
		displayedWidgetPic = widgetPic
	}

	func setup(with delegate: ImagesCellViewDelegate, forRow row: Int) {
		providedDelegate = delegate
		providedRow = row
	}
}
