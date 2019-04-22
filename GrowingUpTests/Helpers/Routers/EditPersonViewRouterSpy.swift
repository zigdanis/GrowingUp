//
//  EditPersonViewRouterSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

class EditPersonViewRouterSpy: EditPersonViewRouter {

    var dismissCalled = false

    func dismiss() {
        dismissCalled = true
    }
}
