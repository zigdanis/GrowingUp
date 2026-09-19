#if DEBUG
	import Core
	import CoreData
	import UIKit

	/// Explicit opt-in composition: every UI test gets its own SQLite and image directory.
	/// The normal App Group is never opened or reset by this path.
	@MainActor
	enum UITestComposition {
		static let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

		static func make() throws -> SceneConfigurator? {
			let environment = ProcessInfo.processInfo.environment
			guard let identifier = environment["GROWINGUP_UI_TEST_ID"], UUID(uuidString: identifier) != nil else { return nil }
			let root = URL.applicationSupportDirectory.appendingPathComponent("UITests/\(identifier)")
			if environment["GROWINGUP_UI_RESET"] == "1", FileManager.default.fileExists(atPath: root.path) {
				try FileManager.default.removeItem(at: root)
			}
			try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
			let stack = try UITestStore(url: root.appendingPathComponent("people.sqlite"))
			if environment["GROWINGUP_UI_RESET"] == "1", environment["GROWINGUP_UI_SEED"] == "pinned" {
				try stack.seed()
			}
			let images = UITestImageStore(root: root)
			let persistentGateway = CoreDataPersonsGateway(coreDataStack: stack)
			let failureGateway = UITestFailureGateway(base: persistentGateway, failNextSave: environment["GROWINGUP_UI_FAIL_SAVE"] == "1")
			let gateway = CachePersonsGateway(coreDataGateway: failureGateway, imageStore: images)
			return SceneConfigurator(
				gateway: gateway, loadImage: images.load, now: { fixedDate }, photoFixtures: (0..<12).map(fixture))
		}

		/// Original deterministic landscape artwork; no device photo-library dependency.
		private static func fixture(_ index: Int) -> UIImage {
			let size = CGSize(width: 900, height: 1200)
			let format = UIGraphicsImageRendererFormat()
			format.scale = 1
			return UIGraphicsImageRenderer(size: size, format: format).image { context in
				let colors: [UIColor] = [.systemTeal, .systemBlue, .systemIndigo]
				colors[index % colors.count].setFill()
				context.fill(CGRect(origin: .zero, size: size))
				UIColor.systemYellow.setFill()
				context.cgContext.fillEllipse(in: CGRect(x: 540, y: 90, width: 200, height: 200))
				for row in 0..<8 {
					let path = UIBezierPath()
					let top = CGFloat(330 + row * 110)
					path.move(to: CGPoint(x: 0, y: top + 200))
					path.addLine(to: CGPoint(x: 280, y: top))
					path.addLine(to: CGPoint(x: 550, y: top + 150))
					path.addLine(to: CGPoint(x: 780, y: top - 60))
					path.addLine(to: CGPoint(x: 900, y: top + 100))
					path.addLine(to: CGPoint(x: 900, y: 1200))
					path.addLine(to: CGPoint(x: 0, y: 1200))
					path.close()
					UIColor(hue: 0.35 + Double(row) * 0.015, saturation: 0.65, brightness: 0.7 - Double(row) * 0.06, alpha: 1).setFill()
					path.fill()
				}
			}
		}
	}

	private final class UITestStore: CoreDataStack {
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

	private final class UITestImageStore: ImageStore {
		let root: URL
		init(root: URL) { self.root = root }

		func save(_ image: PersonImage) async throws {
			guard let data = image.uiImage?.jpegData(compressionQuality: 0.95) else { throw CoreError.missingValue }
			try data.write(to: root.appendingPathComponent(image.cachingKey), options: .atomic)
		}

		func delete(_ image: PersonImage) async throws {
			try FileManager.default.removeItem(at: root.appendingPathComponent(image.cachingKey))
		}

		func load(_ image: PersonImage) async throws -> UIImage {
			let data = try Data(contentsOf: root.appendingPathComponent(image.cachingKey))
			guard let result = UIImage(data: data) else { throw CoreError.missingValue }
			return result
		}
	}

	private final class UITestFailureGateway: PersonsGateway {
		let base: PersonsGateway
		var failNextSave: Bool
		init(base: PersonsGateway, failNextSave: Bool) {
			self.base = base
			self.failNextSave = failNextSave
		}

		private func checkFailure() throws {
			if failNextSave {
				failNextSave = false
				throw CoreError.coreDataSaveFailed
			}
		}

		func add(parameters: AddPersonParameters) async throws -> Person {
			try checkFailure()
			return try await base.add(parameters: parameters)
		}

		func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person {
			try checkFailure()
			return try await base.edit(person: person, with: parameters)
		}

		func remove(person: Person) async throws { try await base.remove(person: person) }
		func fetchPersons() async throws -> [Person] { try await base.fetchPersons() }
		func fetchWidgetPersons() async throws -> [Person] { try await base.fetchWidgetPersons() }
	}
#endif
