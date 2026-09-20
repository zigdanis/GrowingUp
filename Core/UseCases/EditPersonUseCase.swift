//
//  EditPersonUseCase.swift
//  GrowingUp
//
//  Created by zigdanis on 16/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

public protocol EditPersonUseCase {
	func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person
}
