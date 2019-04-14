//
//  EmptyPersonViewRouterSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

final class EmptyPersonViewRouterSpy: EmptyPersonViewRouter {

	var didCallPresentAddPerson = false

	func presentAddPerson(addPersonPresenterDelegate: EditPersonPresenterDelegate?) {
		didCallPresentAddPerson = true
	}
}
