//
//  RemovePersonUseCase.swift
//  Core
//
//  Created by zigdanis on 24/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

public protocol RemovePersonUseCase {
	func remove(person: Person) async throws
}
