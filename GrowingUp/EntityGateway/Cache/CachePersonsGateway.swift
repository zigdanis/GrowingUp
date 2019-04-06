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
	private let tasksManager = TaskManagerOnGCD()

	init(coreDataGateway: CoreDataPersonsGateway) {
		self.coreDataGateway = coreDataGateway
	}

	func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {

		var tasks = [Task]()
		if let appPicSaving = appPicSavingTask(for: parameters) {
			tasks.append(appPicSaving)
		}
		if let widgetPicSaving = widgetPicSavingTask(for: parameters) {
			tasks.append(widgetPicSaving)
		}
		tasks.append(coreDataSave(for: parameters))

		// TaskManager save App Pic
		// TaskManager save widget Pic
		// TaskManager save Person to CoreData

		// Call me when you will finish with all of that
		coreDataGateway.add(parameters: parameters, completionHandler: completionHandler)
	}

	private func coreDataSave(for parameters: AddPersonParameters) -> Task {
		return {
			let moc = CoreDataStackImplementation.sharedInstance
				.persistentContainer.newBackgroundContext()
			var isCompleted = false
			let coreData = CoreDataPersonsGateway(viewContext: moc)
			coreData.add(parameters: parameters, completionHandler: { result in
				do {
					try _ = result.get()
					isCompleted = true
				} catch {
					isCompleted = false
				}
			})
			return isCompleted
		}
	}

	private func appPicSavingTask(for parameters: AddPersonParameters) -> Task? {
		guard let appPic = parameters.appImage?.uiImage else { return nil }
		guard let appPicId = parameters.appImage?.id else { return nil }
		return {
			do {
				try Disk.save(appPic, to: .documents, as: appPicId.uuidString)
				return true
			} catch {
				return false
			}
		}
	}

	private func widgetPicSavingTask(for parameters: AddPersonParameters) -> Task? {
		guard let widgetPic = parameters.widgetImage?.uiImage else { return nil }
		guard let widgetPicId = parameters.widgetImage?.id else { return nil }
		return {
			do {
				try Disk.save(widgetPic, to: .documents, as: widgetPicId.uuidString)
				return true
			} catch {
				return false
			}
		}
	}
}
