//
//  FavoritePersonsUseCase.swift
//  Core
//
//  Created by zigdanis on 13/09/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public protocol FavoritePersonsUseCase {
	var currentFavs: Int { get set }
}

public final class FavoritePersonsUseCaseImplementation: FavoritePersonsUseCase {

	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
		loadFavorites()
	}

	private func loadFavorites() {
		personsGateway.fetchPersons { result in
			switch result {
			case .success(let value): self.currentFavs = value.count
			case .failure(let error): Logging.logError(error)
			}
		}
	}

	// MARK: - FavoritePersonsUseCase

	public var currentFavs: Int = 0
}
