//
//  AddPersonViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

class AddPersonViewSpy: AddPersonView {

    var addButtonEnabledState: Bool?
    var cancelButtonEnabledState: Bool?
    var displayAddPersonErrorTitle: String?
    var displayAddPersonErrorMessage: String?

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

}
