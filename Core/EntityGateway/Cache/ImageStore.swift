//
//  ImageStore.swift
//  Core
//
//  Copyright © 2026 Danis Ziganshin.
//

public protocol ImageStore {
	func save(_ image: PersonImage) async throws
	func delete(_ image: PersonImage) async throws
}
