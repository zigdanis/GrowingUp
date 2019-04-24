//
//  PersonsListViewSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp
@testable import Core

class PersonsListViewSpy: PersonsListView {

	var didCallUpdateListOfScreens = false
	var didCallScrollToPage = false

	func updateListOfScreens() {
		didCallUpdateListOfScreens = true
	}

	func scrollToPage(atIndex index: Int) {
		didCallScrollToPage = true
	}
}
