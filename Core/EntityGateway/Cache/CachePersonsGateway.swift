//
//  CachePersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 02/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Disk
import Foundation

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

	public func edit(
		person: Person, with parameters: AddPersonParameters,
		completionHandler: @escaping EditPersonEntityGatewayCompletionHandler
	) {
		// Core Data
		coreDataGateway.edit(person: person, with: parameters, completionHandler: completionHandler)
		// Reconcile stored image files with the edited parameters: save any newly
		// picked image, and delete the previously stored file whenever its slot was
		// cleared or replaced (its id no longer matches what is being saved).
		var tasks = [Task]()
		if let appPicSaving = appPicSavingTask(for: parameters) {
			tasks.append(appPicSaving)
		}
		if let appPicDelete = outdatedAppPicDeleteTask(person: person, parameters: parameters) {
			tasks.append(appPicDelete)
		}
		if let widgetPicSaving = widgetPicSavingTask(for: parameters) {
			tasks.append(widgetPicSaving)
		}
		if let widgetPicDelete = outdatedWidgetPicDeleteTask(person: person, parameters: parameters) {
			tasks.append(widgetPicDelete)
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

	/// Delete task for a previously stored app picture that the edit no longer keeps —
	/// either the slot was cleared (`appImage == nil`) or replaced with a different
	/// image. Returns `nil` when the stored picture is unchanged, so an untouched edit
	/// never deletes the file it is about to keep.
	private func outdatedAppPicDeleteTask(person: Person, parameters: AddPersonParameters) -> Task? {
		guard let storedId = person.appPicId, storedId != parameters.appImage?.id else { return nil }
		return appPicDeleteTask(for: person)
	}

	private func outdatedWidgetPicDeleteTask(person: Person, parameters: AddPersonParameters) -> Task? {
		guard let storedId = person.widgetPicId, storedId != parameters.widgetImage?.id else { return nil }
		return widgetPicDeleteTask(for: person)
	}
}
