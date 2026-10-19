import Foundation

enum SQLiteStoreAccess {
	/// All app and widget loads share an exclusive cross-process claim, including recovery and its retry.
	static func coordinate<T>(at url: URL, operation: (URL) throws -> T) throws -> T {
		var coordinationError: NSError?
		var result: Result<T, Error>?
		// Claim the stable parent directory: the main file can be absent or move during recovery.
		NSFileCoordinator(filePresenter: nil).coordinate(
			writingItemAt: url.deletingLastPathComponent(), options: [], error: &coordinationError
		) { parent in
			result = Result { try operation(parent.appendingPathComponent(url.lastPathComponent)) }
		}
		if let coordinationError { throw coordinationError }
		guard let result else { throw CoreError.coreDataInit }
		return try result.get()
	}
}
