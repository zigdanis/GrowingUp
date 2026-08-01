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

	public func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {
		Task {
			do {
				await complete(.success(try await add(parameters: parameters)), using: completionHandler)
			} catch let error as CoreError {
				await complete(.failure(error), using: completionHandler)
			} catch {
				await complete(.failure(CoreError(error: error)), using: completionHandler)
			}
		}
	}

	public func add(parameters: AddPersonParameters) async throws -> Person {
		try Task.checkCancellation()
		let savedImages = try await save(newImages(in: parameters))
		do {
			try Task.checkCancellation()
			return try await coreDataGateway.add(parameters: parameters)
		} catch {
			await deleteBestEffort(savedImages)
			throw error
		}
	}

	public func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		coreDataGateway.fetchPersons(completionHandler: completionHandler)
	}

	public func fetchPersons() async throws -> [Person] {
		try await coreDataGateway.fetchPersons()
	}

	public func fetchWidgetPersons(completion: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		coreDataGateway.fetchWidgetPersons(completion: completion)
	}

	public func fetchWidgetPersons() async throws -> [Person] {
		try await coreDataGateway.fetchWidgetPersons()
	}

	public func edit(
		person: Person, with parameters: AddPersonParameters,
		completionHandler: @escaping EditPersonEntityGatewayCompletionHandler
	) {
		Task {
			do {
				await complete(.success(try await edit(person: person, with: parameters)), using: completionHandler)
			} catch let error as CoreError {
				await complete(.failure(error), using: completionHandler)
			} catch {
				await complete(.failure(CoreError(error: error)), using: completionHandler)
			}
		}
	}

	public func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person {
		try Task.checkCancellation()
		let savedImages = try await save(newImages(in: parameters))
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

	public func remove(person: Person, completionHandler: @escaping RemovePersonEntityGatewayCompletionHandler) {
		Task {
			do {
				try await remove(person: person)
				await complete(.success(()), using: completionHandler)
			} catch let error as CoreError {
				await complete(.failure(error), using: completionHandler)
			} catch {
				await complete(.failure(CoreError(error: error)), using: completionHandler)
			}
		}
	}

	public func remove(person: Person) async throws {
		try Task.checkCancellation()
		try await coreDataGateway.remove(person: person)
		await deleteBestEffort(storedImages(for: person))
	}

	// MARK: - Images

	private func newImages(in parameters: AddPersonParameters) -> [PersonImage] {
		[parameters.appImage, parameters.widgetImage].compactMap { image in
			guard image?.uiImage != nil else { return nil }
			return image
		}
	}

	private func storedImages(for person: Person) -> [PersonImage] {
		[PersonImage(id: person.appPicId), PersonImage(id: person.widgetPicId)].compactMap { $0 }
	}

	private func outdatedImages(for person: Person, parameters: AddPersonParameters) -> [PersonImage] {
		var images = [PersonImage]()
		if let stored = PersonImage(id: person.appPicId), stored.id != parameters.appImage?.id {
			images.append(stored)
		}
		if let stored = PersonImage(id: person.widgetPicId), stored.id != parameters.widgetImage?.id {
			images.append(stored)
		}
		return images
	}

	private func save(_ images: [PersonImage]) async throws -> [PersonImage] {
		var savedImages = [PersonImage]()
		do {
			for image in images {
				try Task.checkCancellation()
				try await imageStore.save(image)
				savedImages.append(image)
			}
			return savedImages
		} catch {
			await deleteBestEffort(savedImages)
			throw error
		}
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

	private func complete<Value>(
		_ result: Result<Value, CoreError>, using completion: @escaping (Result<Value, CoreError>) -> Void
	) async {
		await MainActor.run { completion(result) }
	}
}
