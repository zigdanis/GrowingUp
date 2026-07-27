//
//  CoreDataStack.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import CoreData
import Foundation

public protocol CoreDataStack {
  var persistentContainer: NSPersistentContainer { get }
}

public final class CoreDataStackImplementation: CoreDataStack {

  public static let sharedInstance = CoreDataStackImplementation()

  public lazy var persistentContainer: NSPersistentContainer = self.recreatePersistanContainer()

  private func recreatePersistanContainer() -> NSPersistentContainer {
    let fileURL = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupId)?
      .appendingPathComponent("Application Support/GrowingUp.sqlite")
    guard let appGroupURL = fileURL else {
      let message = "Failed to get App Group URL"
      Logging.logError(CoreError(message: message))
      fatalError(message)
    }
    checkAndCreateDirectoryIfNeeded(at: appGroupURL)
    let description = NSPersistentStoreDescription(url: appGroupURL)
    let coreBundle = Bundle(identifier: "pro.ziganshin.Core")!
    let modelURL = coreBundle.url(forResource: "GrowingUp", withExtension: "momd")!
    let model = NSManagedObjectModel(contentsOf: modelURL)!
    let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
    container.persistentStoreDescriptions = [description]
    container.loadPersistentStores(completionHandler: { (description, error) in
      if let error = error as NSError? {
        if error.domain == NSCocoaErrorDomain {
          self.deleteSQLiteStore(for: description.url!)
          _ = self.recreatePersistanContainer()
        } else {
          Logging.logError(CoreError.coreDataInit)
          fatalError("Unresolved error \(error), \(error.userInfo)")
        }
      }
    })
    return container
  }

  // MARK: - Helpers

  private func deleteSQLiteStore(for url: URL) {
    do {
      try FileManager.default.removeItem(at: url)
    } catch let error as NSError {
      Logging.logError(CoreError(title: "\(error.code)", message: error.userInfo.description))
      fatalError("Unresolved error \(error), \(error.userInfo)")
    }
  }

  private func checkAndCreateDirectoryIfNeeded(at path: URL) {
    let directoryPath = path.deletingLastPathComponent()
    do {
      try FileManager.default.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
    } catch {
      let message = "Failed to create directory in App Group folder for .sqlite file at \(directoryPath)"
      Logging.logError(CoreError(message: message))
      fatalError(message)
    }
  }
}
