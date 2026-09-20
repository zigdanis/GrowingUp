//
//  DisplayPersonsUseCase.swift
//  GrowingUp
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

public protocol FetchPersonsUseCase {
	func fetchPersons() async throws -> [Person]
	func fetchWidgetPersons() async throws -> [Person]
}
