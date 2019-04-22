//
//  TasksManager.swift
//  GrowingUp
//
//  Created by zigdanis on 05/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public typealias Task<T> = () -> (Result<T?, CoreError>)
public typealias TasksCompletion<T> = (_ result: Result<T, CoreError>) -> Void

public protocol TaskManager {
	func process<T>(tasks: [Task<T>], withCompletion completion: @escaping TasksCompletion<T>)
}

public final class TaskManagerOnGCD: TaskManager {

	public init() { }

	public func process<T>(tasks: [Task<T>], withCompletion completion: @escaping TasksCompletion<T>) {
		let queue = DispatchQueue.global(qos: .userInitiated)
		let group = DispatchGroup()
		var finalValue: T?
		var finalError: CoreError?
		for task in tasks {
			let workItem = DispatchWorkItem {
				let result = task()
				switch result {
				case .success(let value):
					guard let value = value else { return }
					finalValue = value
				case .failure(let error):
					finalError = error
				}
			}
			queue.async(group: group, execute: workItem)
		}
		group.notify(queue: DispatchQueue.main) {
			if let error = finalError {
				completion(.failure(error))
			} else if let value = finalValue {
				completion(.success(value))
			} else {
				completion(.failure(.missingValue))
			}
		}
	}

}
