//
//  TasksManager.swift
//  GrowingUp
//
//  Created by zigdanis on 05/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public typealias Task = () throws -> Void
public typealias TasksCompletion = (_ result: CoreError?) -> Void

public protocol TaskManager {
	func process(tasks: [Task], withCompletion completion: TasksCompletion?)
}

public final class TaskManagerOnGCD: TaskManager {

	public init() { }

	public func process(tasks: [Task], withCompletion completion: TasksCompletion? = nil) {
		// TODO: - Guard return, call callback if tasks.isEmpty
		let queue = DispatchQueue.global(qos: .utility)
		let group = DispatchGroup()
		var finalError: CoreError?
		for task in tasks {
			let workItem = DispatchWorkItem {
				do {
					try task()
				} catch let error as CoreError {
					finalError = error
				} catch {
					let err = CoreError(error: error)
					finalError = err
				}
			}
			queue.async(group: group, execute: workItem)
		}
		group.notify(queue: DispatchQueue.main) {
			completion?(finalError)
		}
	}

}
