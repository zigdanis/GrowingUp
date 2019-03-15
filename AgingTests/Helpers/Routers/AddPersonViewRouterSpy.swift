//
//  AddPersonViewRouterSpy.swift
//  AgingTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import Aging

class AddPersonViewRouterSpy: AddPersonViewRouter {
    
    var dismissCalled = false
    
    func dismiss() {
        dismissCalled = true
    }
}
