//
//  TaskManagerSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 06/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

class TaskManagerSpy: TaskManager {

	var processTasksCalled = false

	func process<T>(tasks: [Task<T>], withCompletion completion: @escaping TasksCompletion<T>) {
		processTasksCalled = true
		completion(.failure(.unknownError))
	}
}
