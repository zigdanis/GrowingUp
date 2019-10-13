//
//  TaskManagerSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 06/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

class TaskManagerSpy: TaskManager {

	var processTasksCalled = false
	var expectedResultValue: Any!
	var expectedError: CoreError!
	var shouldSucceed = true

	func process(tasks: [Task]) {
		processTasksCalled = true
	}
}
