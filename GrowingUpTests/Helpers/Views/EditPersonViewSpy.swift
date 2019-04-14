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

    var addButtonEnabledState: Bool?
    var cancelButtonEnabledState: Bool?
    var displayAddPersonErrorTitle: String?
    var displayAddPersonErrorMessage: String?
	var displayedScreenTitle: String?
	var showedAppPicImagePicker = false
	var showedWidgetPicImagePicker = false

    func updateAddButtonState(isEnabled enabled: Bool) {
        addButtonEnabledState = enabled
    }

    func updateCancelButtonState(isEnabled enabled: Bool) {
        cancelButtonEnabledState = enabled
    }

	func displayAddPersonError(title: String, message: String) {
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
}
