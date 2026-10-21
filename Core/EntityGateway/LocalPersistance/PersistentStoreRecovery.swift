import CoreData
import Foundation

enum PersistentStoreRecovery {
	/// Only explicit model incompatibility permits moving a store. Generic migration, permission,
	/// protection and I/O failures (including wrappers with underlying errors) leave it untouched.
	static func shouldBackUp(_ error: NSError) -> Bool {
		error.domain == NSCocoaErrorDomain
			&& [NSPersistentStoreIncompatibleVersionHashError, NSMigrationMissingSourceModelError, NSMigrationMissingMappingModelError]
				.contains(error.code)
	}
}
