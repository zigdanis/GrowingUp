//
//  FetchPersonsUseCaseSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 03/11/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import Core

final class FetchPersonsUseCaseSpy: FetchPersonsUseCase {

	var completionResult: Result<[Person], CoreError>!

	func fetchPersons(completionHandler: @escaping FetchPersonsUseCaseCompletionHandler) {
		completionHandler(completionResult)
	}

	func fetchWidgetPersons(completion: @escaping FetchPersonsUseCaseCompletionHandler) {
		completion(completionResult)
	}
}
