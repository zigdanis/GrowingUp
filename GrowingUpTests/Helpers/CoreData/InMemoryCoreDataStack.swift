//
//  InMempryCoreDataStack.swift
//  GrowingUpTests
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import CoreData

@testable import GrowingUp
@testable import Core

class InMemoryCoreDataStack: CoreDataStack {

    lazy var persistentContainer: NSPersistentContainer = {
		let coreBundle = Bundle(identifier: "pro.ziganshin.Core")!
		let modelURL = coreBundle.url(forResource: "GrowingUp", withExtension: "momd")!
		let model = NSManagedObjectModel(contentsOf: modelURL)!
		let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
		let persistentStoreDescription = NSPersistentStoreDescription()
        persistentStoreDescription.type = NSInMemoryStoreType

        container.persistentStoreDescriptions = [persistentStoreDescription]
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

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

    func fakeEntity<T: NSManagedObject>(withType type: T.Type) -> T {
        return persistentContainer.viewContext.addEntity(withType: type)!
    }
}
