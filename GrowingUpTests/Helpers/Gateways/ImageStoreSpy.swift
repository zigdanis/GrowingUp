//
//  ImageStoreSpy.swift
//  GrowingUpTests
//
//  Copyright © 2026 Danis Ziganshin.
//

import Foundation

@testable import Core

final class ImageStoreSpy: ImageStore {

	var savedImages = [PersonImage]()
	var savedOriginals = [PersonImage]()
	var deletedImages = [PersonImage]()
	var saveErrorAtCall: Int?
	var deleteError: Error?
	var onSave: (() -> Void)?
	var onDelete: (() -> Void)?

	func save(_ image: PersonImage) async throws {
		onSave?()
		if saveErrorAtCall == savedImages.count + savedOriginals.count + 1 {
			throw CoreError.unknownError
		}
		savedImages.append(image)
	}

	func saveOriginal(_ image: PersonImage) async throws {
		onSave?()
		if saveErrorAtCall == savedImages.count + savedOriginals.count + 1 {
			throw CoreError.unknownError
		}
		savedOriginals.append(image)
	}

	func delete(_ image: PersonImage) async throws {
		onDelete?()
		deletedImages.append(image)
		if let deleteError {
			throw deleteError
		}
	}
}
