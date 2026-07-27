//
//  TasksManager.swift
//  GrowingUp
//
//  Created by zigdanis on 05/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public typealias Task = () throws -> Void

public protocol TaskManager {
	func process(tasks: [Task])
}

public final class TaskManagerOnGCD: TaskManager {

	public init() {}

	public func process(tasks: [Task]) {
		guard !tasks.isEmpty else { return }
		let queue = DispatchQueue.global(qos: .utility)
		let group = DispatchGroup()
		for task in tasks {
			let workItem = DispatchWorkItem {
				do {
					try task()
				} catch {}
			}
			queue.async(group: group, execute: workItem)
		}
	}

}
