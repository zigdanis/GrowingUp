import CoreData
import Foundation

public final class CoreDataStackImplementation: CoreDataStack {
	public static let sharedInstance = CoreDataStackImplementation()

	private let lock = NSLock()
	private var loadedContainer: NSPersistentContainer?
	private let makeContainer: () throws -> NSPersistentContainer
	private let loadStore: (NSPersistentContainer) throws -> Void
	/// Where the photo files lie that a store set aside keeps with it; nil keeps none.
	private let photosDirectory: URL?

	private convenience init() {
		self.init(makeContainer: Self.makeSharedContainer, photosDirectory: try? Self.appGroupDirectory())
	}

	/// Injection keeps load failures and the single recovery attempt testable without an App Group entitlement.
	init(
		makeContainer: @escaping () throws -> NSPersistentContainer,
		photosDirectory: URL? = nil,
		loadStore: @escaping (NSPersistentContainer) throws -> Void = CoreDataStackImplementation.loadPersistentStores
	) {
		self.makeContainer = makeContainer
		self.photosDirectory = photosDirectory
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
						keepPhotos(in: backup)
					}
					do {
						try loadStore(container)
					} catch {
						guard PersistentStoreRecovery.shouldBackUp(error as NSError) else { throw error }
						Logging.logError(CoreError(error: error))
						let cause = PreservedStoreCause.incompatibleModel(code: (error as NSError).code)
						let backup = try SQLiteStoreBackup().moveStore(at: coordinatedURL, cause: cause)
						Logging.logWarning("Incompatible Core Data store preserved at \(backup.path)")
						keepPhotos(in: backup)
						// Retry once on the same container, so callers receive the successfully loaded store.
						try loadStore(container)
					}
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

	/// Links the loose photo files into a store just set aside, while the new store is still empty, so every one of them
	/// belongs to it. A failure only leaves the pass to the app's next refresh; it never stops the store from loading.
	private func keepPhotos(in backup: URL) {
		guard let photosDirectory else { return }
		do {
			let manifest = try PreservedStoreManifest.read(in: backup) ?? PreservedStoreManifest(preservedAt: Date(), cause: .unknown)
			try PreservedStoreLibrary.keepPhotos(from: photosDirectory, in: backup, manifest: manifest)
		} catch {
			Logging.logError(CoreError(error: error))
		}
	}

	/// The App Group container the app and the widget share; photos lie at its top level.
	static func appGroupDirectory() throws -> URL {
		guard let appGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupId) else {
			throw CoreError(message: "Failed to get App Group URL")
		}
		return appGroup
	}

	static func storeURL(in appGroup: URL) -> URL {
		appGroup.appendingPathComponent("Application Support/GrowingUp.sqlite")
	}

	private static func makeSharedContainer() throws -> NSPersistentContainer {
		let url = storeURL(in: try appGroupDirectory())
		try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		guard let modelURL = Bundle(for: CoreDataPerson.self).url(forResource: "GrowingUp", withExtension: "momd"),
			let model = NSManagedObjectModel(contentsOf: modelURL)
		else { throw CoreError.coreDataInit }
		let container = NSPersistentContainer(name: "GrowingUp", managedObjectModel: model)
		container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]
		return container
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
