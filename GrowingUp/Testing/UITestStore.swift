#if DEBUG
	import Core
	import CoreData

	final class UITestStore: CoreDataStack {
		let persistentContainer: NSPersistentContainer

		init(url: URL) throws {
			let bundle = Bundle(for: CoreDataPerson.self)
			let modelURL = bundle.url(forResource: "GrowingUp", withExtension: "momd")!
			let model = NSManagedObjectModel(contentsOf: modelURL)!
			persistentContainer = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
			let description = NSPersistentStoreDescription(url: url)
			description.shouldAddStoreAsynchronously = false
			persistentContainer.persistentStoreDescriptions = [description]
			var loadError: Error?
			persistentContainer.loadPersistentStores { _, error in loadError = error }
			if let loadError { throw loadError }
		}

		func seed() throws {
			let context = persistentContainer.viewContext
			try context.performAndWait {
				let access = try AccessToWidget.sharedInstance(in: context)
				for (index, name) in ["Alice", "Boris", "Clara"].enumerated() {
					let person = CoreDataPerson(context: context)
					person.id = String(format: "00000000-0000-0000-0000-%012d", index + 1)
					person.name = name
					person.birthdate = Date(timeIntervalSince1970: 1_600_000_000)
					person.createdDate = Date(timeIntervalSince1970: Double(index))
					person.accessToWidget = access
				}
				try context.save()
			}
		}
	}
#endif
