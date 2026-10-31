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
			if seed == .demo || seed == .demoMia { return try seedDemo(count: seed == .demo ? 4 : 1) }
			let context = persistentContainer.viewContext
			var widgetPictures: [UUID] = []
			try context.performAndWait {
				let access = try AccessToWidget.sharedInstance(in: context)
				let counts: [UITestSeed: Int] = [.sixPinned: 6, .fourPinned: 4, .onePerson: 1]
				let names = Array(["Alice", "Boris", "Clara", "Daria", "Evan", "Farah"].prefix(counts[seed, default: 3]))
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
					if seed == .sixPinned || seed == .fourPinned {
						person.birthdate = Calendar.current.date(byAdding: UITestStore.sixPinnedAges[index], to: now)!
						// Clara and Farah have no photo, so the widget shows both photo and monogram tiles. The others share
						// one portrait fixture as widget and app photo, so a mosaic tile and its full-screen page match.
						if ![2, 5].contains(index) {
							let picture = UUID()
							person.widgetPicId = picture.uuidString
							person.appPicId = picture.uuidString
							widgetPictures.append(picture)
						}
					}
					person.createdDate = Date(timeIntervalSince1970: Double(index))
					person.accessToWidget = access
				}
				try context.save()
			}
			return widgetPictures
		}

		/// Seeds the first `count` App Store demo people, each pinned with a photo, and returns their picture IDs in order.
		private func seedDemo(count: Int) throws -> [UUID] {
			let context = persistentContainer.viewContext
			var pictures: [UUID] = []
			try context.performAndWait {
				let access = try AccessToWidget.sharedInstance(in: context)
				for (index, demo) in Self.demoPeople.prefix(count).enumerated() {
					let person = CoreDataPerson(context: context)
					let picture = UUID()
					person.id = String(format: "00000000-0000-0000-0000-%012d", index + 1)
					person.name = demo.name
					person.birthdate = Calendar.current.date(from: demo.birthday)!
					person.widgetPicId = picture.uuidString
					person.appPicId = picture.uuidString
					person.createdDate = Date(timeIntervalSince1970: Double(index))
					person.accessToWidget = access
					pictures.append(picture)
				}
				try context.save()
			}
			return pictures
		}

		/// The App Store demo people with the birthdays its capture enters; on 16 January 2027 Leo has his birthday.
		private static let demoPeople = [
			(name: "Mia", birthday: DateComponents(year: 2026, month: 7, day: 16)),
			(name: "Leo", birthday: DateComponents(year: 2021, month: 1, day: 16)),
			(name: "Mango", birthday: DateComponents(year: 2024, month: 10, day: 16)),
			(name: "Teddy", birthday: DateComponents(year: 2026, month: 1, day: 15))
		]

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
