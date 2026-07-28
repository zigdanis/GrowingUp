//
//  EmptyPersonViewRouterSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@testable import Core
@testable import GrowingUp

final class EmptyPersonViewRouterSpy: EmptyPersonViewRouter {

	var didCallPresentAddPerson = false

	func presentAddPerson(addPersonPresenterDelegate: EditPersonPresenterDelegate?) {
		didCallPresentAddPerson = true
	}
}
