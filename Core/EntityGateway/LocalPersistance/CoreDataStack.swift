//
//  CoreDataStack.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import CoreData

public protocol CoreDataStack {
    var persistentContainer: NSPersistentContainer { get }
    func saveContext()
}

public final class CoreDataStackImplementation {

    public static let sharedInstance = CoreDataStackImplementation()

    public lazy var persistentContainer: NSPersistentContainer = self.recreatePersistanContainer()

	private func recreatePersistanContainer() -> NSPersistentContainer {
		let fileURL = FileManager.default
			.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupId)?
			.appendingPathComponent("Application Support/GrowingUp.sqlite")
		guard let appGroupURL = fileURL else {
			fatalError("Failed to get App Group URL")
		}
		checkAndCreateDirectoryIfNeeded(at: appGroupURL)
		print("App Group URL = \(appGroupURL)")
		let description = NSPersistentStoreDescription(url: appGroupURL)
		let container = NSPersistentContainer(name: "GrowingUp")
		container.persistentStoreDescriptions = [description]
		container.loadPersistentStores(completionHandler: { (description, error) in
			if let error = error as NSError? {
				if error.domain == NSCocoaErrorDomain {
					self.deleteSQLiteStore(for: description.url!)
					_ = self.recreatePersistanContainer()
				} else {
					fatalError("Unresolved error \(error), \(error.userInfo)")
				}
			}
		})
		return container
	}

    // MARK: - Core Data Saving support

    public func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

	// MARk: - Helpers

	private func deleteSQLiteStore(for url: URL) {
		do {
			try FileManager.default.removeItem(at: url)
		} catch let error as NSError {
			fatalError("Unresolved error \(error), \(error.userInfo)")
		}
	}

	private func checkAndCreateDirectoryIfNeeded(at path: URL) {
		let directoryPath = path.deletingLastPathComponent()
		do {
			try FileManager.default.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
		} catch {
			fatalError("Failed to create directory in App Group folder for .sqlite file at \(directoryPath)")
		}
	}
}
