//
//  PersonsListViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@testable import Core
@testable import GrowingUp

class PersonsListViewSpy: PersonsListView {

	var didCallUpdateListOfScreens = false

	func updateListOfScreens(defaultPage index: Int) {
		didCallUpdateListOfScreens = true
	}

}
