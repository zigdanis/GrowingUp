//
//  AddPersonViewRouterSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

class AddPersonViewRouterSpy: AddPersonViewRouter {

    var dismissCalled = false

    func dismiss() {
        dismissCalled = true
    }
}
