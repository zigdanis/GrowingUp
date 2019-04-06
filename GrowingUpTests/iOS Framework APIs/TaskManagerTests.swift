//
//  TaskManagerTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 06/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp

class TaskManagerTests: XCTestCase {

	var sut: TaskManagerOnGCD!

    override func setUp() {
		sut = TaskManagerOnGCD()
    }

	func test_SUT_QueuedWith3Tasks_CallingAllOfThem() {
		// Given
		var tasks = [Task]()
		var calledJob1 = false
		var calledJob2 = false
		var calledJob3 = false
		tasks.append({ calledJob1 = true; return false })
		tasks.append({ calledJob2 = true; return false })
		tasks.append({ calledJob3 = true; return false })
		let expectedToFinish = expectation(description: "Expected to finish all 3 jobs")
		// When
		sut.process(tasks: tasks) { _ in
			// Then
			XCTAssertTrue(calledJob1 && calledJob2 && calledJob3, "Expected to call all 3 jobs")
			expectedToFinish.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_QueuedWith3SucceddedTasks_CallingCompletionWithSuccess() {
		// Given
		var tasks = [Task]()
		tasks.append({ return true })
		tasks.append({ return true })
		tasks.append({ return true })
		let workIsDone = expectation(description: "Expected to call all 3 tasks")
		// When
		sut.process(tasks: tasks) { isSuccedded in
			// Then
			XCTAssertTrue(isSuccedded, "Expected to call completion with success")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1, handler: nil)
	}

	func test_SUT_QueuedWithFailingTask_CallingCompletionWithFailing() {
		// Given
		var tasks = [Task]()
		tasks.append({ return true })
		tasks.append({ return false })
		tasks.append({ return true })
		let workIsDone = expectation(description: "Expected to call all 3 tasks")
		// When
		sut.process(tasks: tasks) { isSuccedded in
			// Then
			XCTAssertFalse(isSuccedded, "Expected to call completion with failure")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1, handler: nil)
	}

	func test_SUT_WhenFinished_CallCallbackOnMainThread() {
		// Given
		let workIsDone = expectation(description: "Expected to finish all jobs")
		// When
		sut.process(tasks: []) { _ in
			// Then
			XCTAssertTrue(Thread.isMainThread, "Expected to be called on main thread")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_CallingJobs_OnNonMainThread() {
		// Given
		var tasks = [Task]()
		tasks.append({
			XCTAssertFalse(Thread.isMainThread, "Expected to be called on global queue")
			return false
		})
		let workIsDone = expectation(description: "Expected to finish all jobs")
		// When
		sut.process(tasks: tasks) { _ in
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}
}
