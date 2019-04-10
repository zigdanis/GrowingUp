//
//  CachePersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 02/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import Disk

final class CachePersonsGateway: PersonsGateway {

	let coreDataGateway: CoreDataPersonsGateway
	let taskManager: TaskManager

	init(coreDataGateway: CoreDataPersonsGateway, taskManager: TaskManager) {
		self.coreDataGateway = coreDataGateway
		self.taskManager = taskManager
	}

	func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {

		var tasks = [Task<Person>]()
		if let appPicSaving = appPicSavingTask(for: parameters) {
			tasks.append(appPicSaving)
		}
		if let widgetPicSaving = widgetPicSavingTask(for: parameters) {
			tasks.append(widgetPicSaving)
		}
		tasks.append(coreDataSave(for: parameters))

		taskManager.process(tasks: tasks, withCompletion: completionHandler)
	}

	func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler) {
	}

	// MARK: - Private

	private func coreDataSave(for parameters: AddPersonParameters) -> Task<Person> {
		return {
			let moc = CoreDataStackImplementation.sharedInstance
				.persistentContainer.newBackgroundContext()
			let result = self.coreDataGateway.add(parameters: parameters, with: moc)
			return result.map({ $0 as Person? })
		}
	}

	private func appPicSavingTask(for parameters: AddPersonParameters) -> Task<Person>? {
		guard let appPic = parameters.appImage?.uiImage else { return nil }
		guard let appPicId = parameters.appImage?.id else { return nil }
		return {
			do {
				try Disk.save(appPic, to: .documents, as: appPicId.uuidString)
				return .success(nil)
			} catch {
				let coreError = CoreError(message: error.localizedDescription)
				return .failure(coreError)
			}
		}
	}

	private func widgetPicSavingTask(for parameters: AddPersonParameters) -> Task<Person>? {
		guard let widgetPic = parameters.widgetImage?.uiImage else { return nil }
		guard let widgetPicId = parameters.widgetImage?.id else { return nil }
		return {
			do {
				try Disk.save(widgetPic, to: .documents, as: widgetPicId.uuidString)
				return .success(nil)
			} catch {
				let coreError = CoreError(message: error.localizedDescription)
				return .failure(coreError)
			}
		}
	}
}
