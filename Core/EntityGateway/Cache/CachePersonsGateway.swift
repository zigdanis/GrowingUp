//
//  CachePersonsGateway.swift
//  GrowingUp
//
//  Created by zigdanis on 02/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

public final class CachePersonsGateway: PersonsGateway {

	let coreDataGateway: PersonsGateway
	let imageStore: ImageStore

	public init(coreDataGateway: PersonsGateway, imageStore: ImageStore) {
		self.coreDataGateway = coreDataGateway
		self.imageStore = imageStore
	}

	public func add(parameters: AddPersonParameters) async throws -> Person {
		try Task.checkCancellation()
		let savedImages = try await saveNewImages(of: parameters)
		do {
			try Task.checkCancellation()
			return try await coreDataGateway.add(parameters: parameters)
		} catch {
			await deleteBestEffort(savedImages)
			throw error
		}
	}

	public func fetchPersons() async throws -> [Person] {
		try await coreDataGateway.fetchPersons()
	}

	public func fetchWidgetPersons() async throws -> [Person] {
		try await coreDataGateway.fetchWidgetPersons()
	}

	public func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person {
		try Task.checkCancellation()
		let savedImages = try await saveNewImages(of: parameters)
		do {
			try Task.checkCancellation()
			let updatedPerson = try await coreDataGateway.edit(person: person, with: parameters)
			await deleteBestEffort(outdatedImages(for: person, parameters: parameters))
			return updatedPerson
		} catch {
			await deleteBestEffort(savedImages)
			throw error
		}
	}

	public func reorder(_ ids: [UUID]) async throws {
		try await coreDataGateway.reorder(ids)
	}

	public func remove(person: Person) async throws {
		try Task.checkCancellation()
		try await coreDataGateway.remove(person: person)
		await deleteBestEffort(storedImages(for: person))
	}

	// MARK: - Images

	/// Everything stored for `person`, each file once, whichever roles share it.
	private func storedImages(for person: Person) -> [PersonImage] {
		unique([person.appPicId, person.widgetPicId, person.originalPicId].compactMap { $0 }).map { PersonImage(id: $0) }
	}

	/// What `person` stored that `parameters` no longer refers to in any role: a main picture that became the
	/// original, or one shared with the widget picture, stays.
	private func outdatedImages(for person: Person, parameters: AddPersonParameters) -> [PersonImage] {
		let kept = Set([parameters.appImage, parameters.widgetImage, parameters.originalImage].compactMap { $0?.id })
		return storedImages(for: person).filter { !kept.contains($0.id) }
	}

	/// Stores the pictures and the original of `parameters` that are new, held in memory rather than already stored.
	private func saveNewImages(of parameters: AddPersonParameters) async throws -> [PersonImage] {
		var savedImages = [PersonImage]()
		do {
			for picture in [parameters.appImage, parameters.widgetImage].compactMap({ $0 }) where picture.uiImage != nil {
				try Task.checkCancellation()
				try await imageStore.save(picture)
				savedImages.append(picture)
			}
			if let original = parameters.originalImage, original.uiImage != nil {
				try Task.checkCancellation()
				try await imageStore.saveOriginal(original)
				savedImages.append(original)
			}
			return savedImages
		} catch {
			await deleteBestEffort(savedImages)
			throw error
		}
	}

	private func unique(_ ids: [UUID]) -> [UUID] {
		var seen = Set<UUID>()
		return ids.filter { seen.insert($0).inserted }
	}

	private func deleteBestEffort(_ images: [PersonImage]) async {
		for image in images {
			do {
				try await imageStore.delete(image)
			} catch {
				Logging.logError(CoreError(error: error))
			}
		}
	}
}
