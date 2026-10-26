//
//  ImageStore.swift
//  Core
//
//  Copyright © 2026 Danis Ziganshin.
//

public protocol ImageStore {
	/// Stores a picture the app or the widget shows.
	func save(_ image: PersonImage) async throws
	/// Stores a person's original photo, which only framing reads; see `OriginalPhotoFile`.
	func saveOriginal(_ image: PersonImage) async throws
	/// Removes the picture or original stored under `image`'s identifier, in whichever format it was stored.
	func delete(_ image: PersonImage) async throws
}
