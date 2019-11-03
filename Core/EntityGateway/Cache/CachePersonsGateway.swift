//
//  CachePersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 02/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import Disk

public final class CachePersonsGateway: PersonsGateway {

	let coreDataGateway: PersonsGateway
	let taskManager: TaskManager

	public init(coreDataGateway: PersonsGateway, taskManager: TaskManager) {
		self.coreDataGateway = coreDataGateway
		self.taskManager = taskManager
	}

	public func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {
		// Core Data
		coreDataGateway.add(parameters: parameters, completionHandler: completionHandler)
		// Saving Images
		var tasks = [Task]()
		if let appPicSaving = appPicSavingTask(for: parameters) {
			tasks.append(appPicSaving)
		}
		if let widgetPicSaving = widgetPicSavingTask(for: parameters) {
			tasks.append(widgetPicSaving)
		}
		taskManager.process(tasks: tasks)
	}

	public func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		coreDataGateway.fetchPersons(completionHandler: completionHandler)
	}

	public func fetchWidgetPersons(completion: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		coreDataGateway.fetchWidgetPersons(completion: completion)
	}

	public func edit(person: Person, with parameters: AddPersonParameters, completionHandler: @escaping EditPersonEntityGatewayCompletionHandler) {
		// Core Data
		coreDataGateway.edit(person: person, with: parameters, completionHandler: completionHandler)
		// Saving Images
		var tasks = [Task]()
		if let appPicSaving = appPicSavingTask(for: parameters) {
			tasks.append(appPicSaving)
		}
		if let widgetPicSaving = widgetPicSavingTask(for: parameters) {
			tasks.append(widgetPicSaving)
		}
		taskManager.process(tasks: tasks)
	}

	public func remove(person: Person, completionHandler: @escaping RemovePersonEntityGatewayCompletionHandler) {
		// Core Data
		coreDataGateway.remove(person: person, completionHandler: completionHandler)
		// Deleting Images
		var tasks = [Task]()
		if let appPicDelete = appPicDeleteTask(for: person) {
			tasks.append(appPicDelete)
		}
		if let widgetPicDelete = widgetPicDeleteTask(for: person) {
			tasks.append(widgetPicDelete)
		}
		taskManager.process(tasks: tasks)
	}

	// MARK: - Private

	private func appPicSavingTask(for parameters: AddPersonParameters) -> Task? {
		guard let appPic = parameters.appImage?.uiImage else { return nil }
		guard let appPicKey = parameters.appImage?.cachingKey else { return nil }
		ImagesCache.memoryCache.setValue(appPic, forKey: appPicKey, expires: Date().addingTimeInterval(200))
		let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
		return {
			try Disk.save(appPic, to: directory, as: appPicKey)
		}
	}

	private func widgetPicSavingTask(for parameters: AddPersonParameters) -> Task? {
		guard let widgetPic = parameters.widgetImage?.uiImage else { return nil }
		guard let widgetPicKey = parameters.widgetImage?.cachingKey else { return nil }
		ImagesCache.memoryCache.setValue(widgetPic, forKey: widgetPicKey, expires: Date().addingTimeInterval(200))
		let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
		return {
			try Disk.save(widgetPic, to: directory, as: widgetPicKey)
		}
	}

	private func appPicDeleteTask(for person: Person) -> Task? {
		guard let appPic = PersonImage(id: person.appPicId) else { return nil }
		ImagesCache.memoryCache.removeValue(forKey: appPic.cachingKey)
		let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
		return {
			try Disk.remove(appPic.cachingKey, from: directory)
		}
	}

	private func widgetPicDeleteTask(for person: Person) -> Task? {
		guard let widgetPic = PersonImage(id: person.widgetPicId) else { return nil }
		ImagesCache.memoryCache.removeValue(forKey: widgetPic.cachingKey)
		let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
		return {
			try Disk.remove(widgetPic.cachingKey, from: directory)
		}
	}
}
