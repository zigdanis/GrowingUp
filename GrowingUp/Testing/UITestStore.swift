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

		func seed(_ seed: UITestSeed = .pinned) throws {
			let context = persistentContainer.viewContext
			try context.performAndWait {
				let access = try AccessToWidget.sharedInstance(in: context)
				let names = seed == .sixPinned ? ["Alice", "Boris", "Clara", "Daria", "Evan", "Farah"] : ["Alice", "Boris", "Clara"]
				for (index, name) in names.enumerated() {
					let person = CoreDataPerson(context: context)
					person.id = String(format: "00000000-0000-0000-0000-%012d", index + 1)
					person.name = name
					person.birthdate = Date(timeIntervalSince1970: 1_600_000_000)
					if seed == .birthdays {
						let month = index == 2 ? 2 : 1
						let day = index == 0 ? 16 : 15
						person.birthdate = Calendar.current.date(from: DateComponents(year: 2020, month: month, day: day, hour: 6, minute: 30))!
					}
					person.createdDate = Date(timeIntervalSince1970: Double(index))
					person.accessToWidget = access
				}
				try context.save()
			}
		}
	}
#endif
