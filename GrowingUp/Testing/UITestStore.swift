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

		/// Seeds the people of `seed` and returns the widget picture IDs whose images the caller stores, in seeding order.
		@discardableResult
		func seed(_ seed: UITestSeed = .pinned, now: Date = Date()) throws -> [UUID] {
			let context = persistentContainer.viewContext
			var widgetPictures: [UUID] = []
			try context.performAndWait {
				let access = try AccessToWidget.sharedInstance(in: context)
				let counts: [UITestSeed: Int] = [.sixPinned: 6, .fourPinned: 4]
				let names = Array(["Alice", "Boris", "Clara", "Daria", "Evan", "Farah"].prefix(counts[seed, default: 3]))
				for (index, name) in names.enumerated() {
					let person = CoreDataPerson(context: context)
					person.id = String(format: "00000000-0000-0000-0000-%012d", index + 1)
					person.name = name
					var birthday = Date(timeIntervalSince1970: 1_600_000_000)
					if seed == .birthdays {
						let month = index == 2 ? 2 : 1
						let day = index == 0 ? 16 : 15
						birthday = Calendar.current.date(from: DateComponents(year: 2020, month: month, day: day, hour: 6, minute: 30))!
					}
					if seed == .sixPinned || seed == .fourPinned {
						birthday = Calendar.current.date(byAdding: UITestStore.sixPinnedAges[index], to: now)!
						// Clara and Farah have no photo, so the widget shows both photo and monogram tiles.
						if ![2, 5].contains(index) {
							let picture = UUID()
							person.widgetPicId = picture.uuidString
							widgetPictures.append(picture)
						}
					}
					person.floatingBirthdate = Person.floatingBirthdate(of: birthday)
					person.createdDate = Date(timeIntervalSince1970: Double(index))
					person.accessToWidget = access
				}
				try context.save()
			}
			return widgetPictures
		}

		/// Offsets from `now` that show each widget tile: years with months, months with days, a newborn,
		/// a birthday today, a birthday in three days, and an adult.
		private static let sixPinnedAges = [
			DateComponents(year: -5, month: -3, day: -12, hour: -1, minute: -30),
			DateComponents(month: -11, day: -4, hour: -22),
			DateComponents(day: -2, hour: -4, minute: -20),
			DateComponents(year: -8, hour: -2),
			DateComponents(year: -4, day: 3),
			DateComponents(year: -30, month: -5, day: -25)
		]
	}
#endif
