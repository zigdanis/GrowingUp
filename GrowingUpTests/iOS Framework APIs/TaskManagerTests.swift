//
//  TaskManagerTests.swift
//  GrowingUpTests
//
//  Created by zigdanis on 06/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import XCTest
@testable import GrowingUp
@testable import Core

class TaskManagerTests: XCTestCase {

	var sut: TaskManagerOnGCD!

    override func setUp() {
		sut = TaskManagerOnGCD()
    }

	func test_SUT_QueuedWith3Tasks_CallingAllOfThem() {
		// Given
		var tasks = [Task<Person>]()
		var calledJob1 = false
		var calledJob2 = false
		var calledJob3 = false
		tasks.append({ calledJob1 = true; return .failure(CoreError.unknownError) })
		tasks.append({ calledJob2 = true; return .failure(CoreError.unknownError) })
		tasks.append({ calledJob3 = true; return .failure(CoreError.unknownError) })
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
		let expectedPerson = Person.createPerson()
		var tasks = [Task<Person>]()
		tasks.append({ return .success(expectedPerson) })
		tasks.append({ return .success(expectedPerson) })
		tasks.append({ return .success(expectedPerson) })
		let workIsDone = expectation(description: "Expected to call all 3 tasks")
		// When
		sut.process(tasks: tasks) { result in
			// Then
			let person = try? result.get()
			XCTAssertEqual(person, expectedPerson, "Expected to call completion with person")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1, handler: nil)
	}

	func test_SUT_QueuedWithFailingTask_CallingCompletionWithFailing() {
		// Given
		var tasks = [Task<Person>]()
		tasks.append({ return .success(.createPerson()) })
		tasks.append({ return .failure(.unknownError) })
		tasks.append({ return .success(.createPerson()) })
		let workIsDone = expectation(description: "Expected to call all 3 tasks")
		// When
		sut.process(tasks: tasks) { result in
			// Then
			let person = try? result.get()
			XCTAssertNil(person, "Expected to return result with failure")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1, handler: nil)
	}

	func test_SUT_WhenFinished_CallCallbackOnMainThread() {
		// Given
		let workIsDone = expectation(description: "Expected to finish all jobs")
		// When
		sut.process(tasks: [Task<Person>]()) { _ in
			// Then
			XCTAssertTrue(Thread.isMainThread, "Expected to be called on main thread")
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}

	func test_SUT_CallingJobs_OnNonMainThread() {
		// Given
		var tasks = [Task<Person>]()
		tasks.append({
			XCTAssertFalse(Thread.isMainThread, "Expected to be called on global queue")
			return .failure(.unknownError)
		})
		let workIsDone = expectation(description: "Expected to finish all jobs")
		// When
		sut.process(tasks: tasks) { _ in
			workIsDone.fulfill()
		}
		waitForExpectations(timeout: 0.1)
	}
}
