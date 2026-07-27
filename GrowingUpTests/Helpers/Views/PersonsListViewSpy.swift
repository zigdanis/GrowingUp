//
//  PersonsListViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
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
