//
//  EmptyPersonPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

@MainActor
protocol EmptyPersonPresenter {
	func addButtonPressed()
}

@MainActor
final class EmptyPersonPresenterImplementation: EmptyPersonPresenter {

	private let router: EmptyPersonViewRouter
	private weak var addPersonPresenterDelegate: EditPersonPresenterDelegate?

	init(router: EmptyPersonViewRouter, addPersonPresenterDelegate: EditPersonPresenterDelegate?) {
		self.router = router
		self.addPersonPresenterDelegate = addPersonPresenterDelegate
	}

	func addButtonPressed() {
		router.presentAddPerson(addPersonPresenterDelegate: addPersonPresenterDelegate)
	}
}
