//
//  EditPersonViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

class EditPersonViewSpy: EditPersonView {

    var barButtonsEnabledState: Bool?
    var displayAddPersonErrorTitle: String?
    var displayAddPersonErrorMessage: String?
	var displayedScreenTitle: String?
	var showedAppPicImagePicker = false
	var showedWidgetPicImagePicker = false
	var removedAppPic = false
	var removedWidgetPic = false
	var didReloadData = false
	var displayedBarButtons = [BarButtonItemStyle]()

	func updateBarButtonsState(isEnabled enabled: Bool) {
        barButtonsEnabledState = enabled
    }

	func displayEditPersonError(title: String, message: String) {
		displayAddPersonErrorTitle = title
		displayAddPersonErrorMessage = message
	}

	func showAppPicImagePickerFor(row: Int, source: ImageCaptureSource) {
		showedAppPicImagePicker = true
	}

	func showWidgetPicImagePickerFor(row: Int, source: ImageCaptureSource) {
		showedWidgetPicImagePicker = true
	}

	func removeAppPic(forRow row: Int) {
		removedAppPic = true
	}

	func removeWidgetPic(forRow row: Int) {
		removedWidgetPic = true
	}

	func displayScreenTitle(title: String) {
		displayedScreenTitle = title
	}

	func displayBarButton(with style: BarButtonItemStyle) {
		displayedBarButtons.append(style)
	}

	func reloadData() {
		didReloadData = true
	}
}
