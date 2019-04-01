//
//  CoreDataStack.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import CoreData

protocol CoreDataStack {
    var persistentContainer: NSPersistentContainer { get }
    func saveContext()
}

class CoreDataStackImplementation {

    static let sharedInstance = CoreDataStackImplementation()

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = self.recreatePersistanContainer()

	private func deleteSQLiteStore(for url: URL) {
		do {
			try FileManager.default.removeItem(at: url)
		} catch let error as NSError {
			fatalError("Unresolved error \(error), \(error.userInfo)")
		}
	}

	private func recreatePersistanContainer() -> NSPersistentContainer {
		let container = NSPersistentContainer(name: "GrowingUp")
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

    func saveContext () {
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
}
