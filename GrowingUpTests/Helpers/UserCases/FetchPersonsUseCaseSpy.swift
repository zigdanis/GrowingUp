//
//  FetchPersonsUseCaseSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 03/11/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@testable import Core

final class FetchPersonsUseCaseSpy: FetchPersonsUseCase {

	var completionResult: Result<[Person], CoreError>!

	func fetchPersons() async throws -> [Person] {
		try completionResult.get()
	}

	func fetchWidgetPersons() async throws -> [Person] {
		try completionResult.get()
	}
}
