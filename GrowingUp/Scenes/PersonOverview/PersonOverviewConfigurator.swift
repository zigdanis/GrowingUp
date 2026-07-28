//
//  PersonOverviewConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 09/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Core
import Foundation

protocol PersonOverviewConfigurator {
	func configure(personOverviewController: PersonOverviewViewController)
}

final class PersonOverviewConfiguratorImplementation: PersonOverviewConfigurator {

	let index: Int
	let person: Person
	weak var editPresenterDelegate: EditPersonPresenterDelegate?

	init(index: Int, person: Person) {
		self.index = index
		self.person = person
	}

	func configure(personOverviewController: PersonOverviewViewController) {
		let router = PersonOverviewRouterImplementation(personOverviewViewController: personOverviewController)
		let presenter = PersonOverviewPresenterImplementation(
			person: person, personOverviewView: personOverviewController, router: router)
		presenter.personPresenterDelegate = editPresenterDelegate
		personOverviewController.presenter = presenter
		personOverviewController.index = index
	}
}
