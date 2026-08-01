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
				let savedImages = try await save(newImages(in: parameters))
				let result = await addToCoreData(parameters: parameters)
				if case .failure = result {
					await deleteBestEffort(savedImages)
				}
				await complete(result, using: completionHandler)
			} catch {
				await complete(.failure(CoreError(error: error)), using: completionHandler)
			}
		}
	}

	public func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		coreDataGateway.fetchPersons(completionHandler: completionHandler)
	}

	public func fetchWidgetPersons(completion: @escaping FetchPersonsEntityGatewayCompletionHandler) {
		coreDataGateway.fetchWidgetPersons(completion: completion)
	}

	public func edit(
		person: Person, with parameters: AddPersonParameters,
		completionHandler: @escaping EditPersonEntityGatewayCompletionHandler
	) {
		Task {
			do {
				let savedImages = try await save(newImages(in: parameters))
				let result = await editInCoreData(person: person, parameters: parameters)
				switch result {
				case .success:
					await deleteBestEffort(outdatedImages(for: person, parameters: parameters))
				case .failure:
					await deleteBestEffort(savedImages)
				}
				await complete(result, using: completionHandler)
			} catch {
				await complete(.failure(CoreError(error: error)), using: completionHandler)
			}
		}
	}

	public func remove(person: Person, completionHandler: @escaping RemovePersonEntityGatewayCompletionHandler) {
		Task {
			let result = await removeFromCoreData(person: person)
			if case .success = result {
				await deleteBestEffort(storedImages(for: person))
			}
			await complete(result, using: completionHandler)
		}
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

	// MARK: - Core Data bridge

	private func addToCoreData(parameters: AddPersonParameters) async -> Result<Person, CoreError> {
		await withCheckedContinuation { continuation in
			coreDataGateway.add(parameters: parameters) { continuation.resume(returning: $0) }
		}
	}

	private func editInCoreData(
		person: Person, parameters: AddPersonParameters
	) async -> Result<Person, CoreError> {
		await withCheckedContinuation { continuation in
			coreDataGateway.edit(person: person, with: parameters) { continuation.resume(returning: $0) }
		}
	}

	private func removeFromCoreData(person: Person) async -> Result<Void, CoreError> {
		await withCheckedContinuation { continuation in
			coreDataGateway.remove(person: person) { continuation.resume(returning: $0) }
		}
	}

	private func complete<Value>(
		_ result: Result<Value, CoreError>, using completion: @escaping (Result<Value, CoreError>) -> Void
	) async {
		await MainActor.run { completion(result) }
	}
}
