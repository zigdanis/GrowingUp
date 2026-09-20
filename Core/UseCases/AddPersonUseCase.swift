//
//  AddPerson.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

public protocol AddPersonUseCase {
	func add(parameters: AddPersonParameters) async throws -> Person
}
