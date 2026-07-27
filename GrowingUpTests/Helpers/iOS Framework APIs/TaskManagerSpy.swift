//
//  TaskManagerSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 06/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

@testable import Core
@testable import GrowingUp

class TaskManagerSpy: TaskManager {

	var processTasksCalled = false
	var processedTasks: [Task] = []

	func process(tasks: [Task]) {
		processTasksCalled = true
		processedTasks = tasks
	}
}
