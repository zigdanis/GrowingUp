//
//  CachePersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 02/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import Disk
import Core

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
		let task: Task<[Person]> = {
			let moc = CoreDataStackImplementation.sharedInstance
				.persistentContainer.newBackgroundContext()
			let result = self.coreDataGateway.fetchPersons(with: moc)
			return result.map({ $0 as [Person]? })
		}

		taskManager.process(tasks: [task], withCompletion: completionHandler)
	}

	func edit(person: Person, with parameters: AddPersonParameters, completionHandler: @escaping EditPersonEntityGatewayCompletionHandler) {

		var tasks = [Task<Person>]()
		if let appPicSaving = appPicSavingTask(for: parameters) {
			tasks.append(appPicSaving)
		}
		if let widgetPicSaving = widgetPicSavingTask(for: parameters) {
			tasks.append(widgetPicSaving)
		}
		tasks.append(coreDataEdit(person: person, with: parameters))

		taskManager.process(tasks: tasks, withCompletion: completionHandler)
	}

	// MARK: - Private

	private func coreDataEdit(person: Person, with parameters: AddPersonParameters) -> Task<Person> {
		return {
			let moc = CoreDataStackImplementation.sharedInstance
				.persistentContainer.newBackgroundContext()
			let result = self.coreDataGateway.edit(person: person, with: parameters, with: moc)
			return result.map({ $0 as Person? })
		}
	}

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
		guard let appPicKey = parameters.appImage?.cachingKey else { return nil }
		return {
			do {
				try Disk.save(appPic, to: .documents, as: appPicKey)
				return .success(nil)
			} catch {
				let coreError = CoreError(message: error.localizedDescription)
				return .failure(coreError)
			}
		}
	}

	private func widgetPicSavingTask(for parameters: AddPersonParameters) -> Task<Person>? {
		guard let widgetPic = parameters.widgetImage?.uiImage else { return nil }
		guard let widgetPicKey = parameters.widgetImage?.cachingKey else { return nil }
		return {
			do {
				try Disk.save(widgetPic, to: .documents, as: widgetPicKey)
				return .success(nil)
			} catch {
				let coreError = CoreError(message: error.localizedDescription)
				return .failure(coreError)
			}
		}
	}
}
