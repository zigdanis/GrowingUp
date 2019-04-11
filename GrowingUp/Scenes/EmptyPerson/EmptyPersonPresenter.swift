//
//  EmptyPersonPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol EmptyPersonPresenter {
	func addButtonPressed()
}

final class EmptyPersonPresenterImplementation: EmptyPersonPresenter {

	private let router: EmptyPersonViewRouter
	private weak var addPersonPresenterDelegate: AddPersonPresenterDelegate?

	init(router: EmptyPersonViewRouter, addPersonPresenterDelegate: AddPersonPresenterDelegate?) {
		self.router = router
		self.addPersonPresenterDelegate = addPersonPresenterDelegate
	}

	func addButtonPressed() {
		router.presentAddPerson(addPersonPresenterDelegate: addPersonPresenterDelegate)
	}
}
