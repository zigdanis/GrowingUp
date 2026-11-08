import Foundation

/// The earlier libraries store recovery set aside; see `PreservedStoreLibrary`.
public protocol PreservedStoreGateway: Sendable {
	/// Every preserved store, newest first.
	func stores() throws -> [PreservedStore]
	/// Keeps the photo files `store` may refer to with it, once.
	func preservePhotos(of store: PreservedStore) throws -> PreservedStore
	/// Notes that `store`'s recovery was reported.
	func markReported(_ store: PreservedStore) throws -> PreservedStore
	/// Writes `store` with its photos as one archive and returns its location.
	func export(_ store: PreservedStore, now: Date) throws -> URL
	/// Deletes `store` for good, at the person's explicit request; loose photo files stay.
	func delete(_ store: PreservedStore) throws
	/// Removes the archives `export` wrote.
	func removeExports()
}
