//
//  TasksManager.swift
//  GrowingUp
//
//  Created by zigdanis on 05/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

typealias Task = () -> (Bool)
typealias TasksCompletion = (_ success: Bool) -> Void

protocol TaskManager {
	func process(tasks: [Task], withCompletion completion: @escaping TasksCompletion)
}

final class TaskManagerOnGCD: TaskManager {

	func process(tasks: [Task], withCompletion completion: @escaping TasksCompletion) {
		let queue = DispatchQueue.global(qos: .userInitiated)
		let group = DispatchGroup()
		var isSuccedded = true
		for task in tasks {
			let workItem = DispatchWorkItem {
				if !task() {
					isSuccedded = false
				}
			}
			queue.async(group: group, execute: workItem)
		}
		group.notify(queue: DispatchQueue.main) {
			completion(isSuccedded)
		}
	}
}
