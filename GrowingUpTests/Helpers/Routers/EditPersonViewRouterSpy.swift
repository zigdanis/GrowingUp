//
//  EditPersonViewRouterSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 15/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

@testable import Core
@testable import GrowingUp

class EditPersonViewRouterSpy: EditPersonViewRouter {

	var dismissCalled = false

	func dismiss() {
		dismissCalled = true
	}
}
