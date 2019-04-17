//
//  EditPersonViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

class EditPersonViewSpy: EditPersonView {

    var barButtonsEnabledState: Bool?
    var displayAddPersonErrorTitle: String?
    var displayAddPersonErrorMessage: String?
	var displayedScreenTitle: String?
	var showedAppPicImagePicker = false
	var showedWidgetPicImagePicker = false
	var didCallDisplayBarButton = false

	func updateBarButtonsState(isEnabled enabled: Bool) {
        barButtonsEnabledState = enabled
    }

	func displayEditPersonError(title: String, message: String) {
		displayAddPersonErrorTitle = title
		displayAddPersonErrorMessage = message
	}

	func showAppPicImagePickerFor(row: Int) {
		showedAppPicImagePicker = true
	}

	func showWidgetPicImagePickerFor(row: Int) {
		showedWidgetPicImagePicker = true
	}

	func displayScreenTitle(title: String) {
		displayedScreenTitle = title
	}

	func displayBarButton(with style: BarButtonItemStyle) {
		didCallDisplayBarButton = true
	}
}
