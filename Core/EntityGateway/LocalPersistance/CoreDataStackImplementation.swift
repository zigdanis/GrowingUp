import CoreData
import Foundation

public final class CoreDataStackImplementation: CoreDataStack {
	public static let sharedInstance = CoreDataStackImplementation()

	private let lock = NSLock()
	private var loadedContainer: NSPersistentContainer?
	private let makeContainer: () throws -> NSPersistentContainer
	private let loadStore: (NSPersistentContainer) throws -> Void

	private convenience init() {
		self.init(makeContainer: Self.makeSharedContainer)
	}

	/// Injection keeps load failures and the single recovery attempt testable without an App Group entitlement.
	init(
		makeContainer: @escaping () throws -> NSPersistentContainer,
		loadStore: @escaping (NSPersistentContainer) throws -> Void = CoreDataStackImplementation.loadPersistentStores
	) {
		self.makeContainer = makeContainer
		self.loadStore = loadStore
	}

	public var persistentContainer: NSPersistentContainer {
		get throws {
			lock.lock()
			defer { lock.unlock() }
			if let loadedContainer { return loadedContainer }
			do {
				let container = try makeContainer()
				guard let url = container.persistentStoreDescriptions.first?.url else { throw CoreError.coreDataInit }
				try SQLiteStoreAccess.coordinate(at: url) { coordinatedURL in
					container.persistentStoreDescriptions[0].url = coordinatedURL
					// Finish an interrupted recovery before SQLite can open a main file without its WAL.
					if let backup = try SQLiteStoreBackup().resumePendingMove(at: coordinatedURL) {
						Logging.logWarning("Interrupted Core Data recovery completed at \(backup.path)")
					}
					do {
						try loadStore(container)
					} catch {
						guard PersistentStoreRecovery.shouldBackUp(error as NSError) else { throw error }
						Logging.logError(CoreError(error: error))
						let backup = try SQLiteStoreBackup().moveStore(at: coordinatedURL)
						Logging.logWarning("Incompatible Core Data store preserved at \(backup.path)")
						// Retry once on the same container, so callers receive the successfully loaded store.
						try loadStore(container)
					}
					try Self.pinLegacyBirthdates(in: container)
				}
				loadedContainer = container
				return container
			} catch {
				Logging.logError(CoreError(error: error))
				// Cache only success: a later widget timeline or app request can retry after unlock.
				throw error
			}
		}
	}

	private static func makeSharedContainer() throws -> NSPersistentContainer {
		guard let appGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupId) else {
			throw CoreError(message: "Failed to get App Group URL")
		}
		let url = appGroup.appendingPathComponent("Application Support/GrowingUp.sqlite")
		try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		guard let modelURL = Bundle(for: CoreDataPerson.self).url(forResource: "GrowingUp", withExtension: "momd"),
			let model = NSManagedObjectModel(contentsOf: modelURL)
		else { throw CoreError.coreDataInit }
		let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
		container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]
		return container
	}

	/// Pins birthdates saved by earlier versions while the store is still claimed, so the app and the widget never
	/// pin them twice. A failure fails the load like any other, so the container is not cached and a later request retries.
	private static func pinLegacyBirthdates(in container: NSPersistentContainer) throws {
		let context = container.newBackgroundContext()
		try context.performAndWait {
			try CoreDataPerson.pinLegacyBirthdates(in: context)
		}
	}

	static func loadPersistentStores(_ container: NSPersistentContainer) throws {
		for description in container.persistentStoreDescriptions {
			description.shouldAddStoreAsynchronously = false
			description.shouldMigrateStoreAutomatically = true
			description.shouldInferMappingModelAutomatically = true
		}
		var loadError: Error?
		container.loadPersistentStores { _, error in
			if let error { loadError = error }
		}
		if let loadError { throw loadError }
	}
}
