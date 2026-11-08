import Foundation

/// The earlier libraries store recovery set aside; see `PreservedStoreLibrary`.
public protocol PreservedStoreGateway: Sendable {
	/// Every preserved store, newest first.
	func stores() throws -> [PreservedStore]
	/// Keeps the photo files `store` may refer to with it, once; the active library's own photos stay out.
	func preservePhotos(of store: PreservedStore, activePhotoIDs: Set<UUID>) throws -> PreservedStore
	/// Notes that `store`'s recovery was reported.
	func markReported(_ store: PreservedStore) throws -> PreservedStore
	/// Writes `store` with its photos as one archive and returns its location.
	func export(_ store: PreservedStore, activePhotoIDs: Set<UUID>, now: Date) throws -> URL
	/// Deletes `store` for good, at the person's explicit request, with the loose photo files only it used; the photos
	/// in `activePhotoIDs` stay. Without them, the loose files all stay.
	func delete(_ store: PreservedStore, activePhotoIDs: Set<UUID>?) throws
	/// Removes the archives `export` wrote.
	func removeExports()
}
