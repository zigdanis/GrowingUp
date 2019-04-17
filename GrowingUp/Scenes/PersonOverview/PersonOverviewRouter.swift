//
//  PersonOverviewRouter.swift
//  GrowingUp
//
//  Created by zigdanis on 09/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import UIKit

protocol PersonOverviewRouter {
	func showEditPerson(presenterDelegate: EditPersonPresenterDelegate?)
}

final class PersonOverviewRouterImplementation: PersonOverviewRouter {

	private let person: Person
	private weak var personOverviewViewController: PersonOverviewViewController?

	init(person: Person, personOverviewViewController: PersonOverviewViewController) {
		self.person = person
		self.personOverviewViewController = personOverviewViewController
	}

	func showEditPerson(presenterDelegate: EditPersonPresenterDelegate?) {
		let configurator = EditPersonConfiguratorImplementation(person: person, editPersonPresenterDelegate: presenterDelegate)
		let viewController = EditPersonViewController(configurator: configurator)
		let navigationController = UINavigationController(rootViewController: viewController)
		personOverviewViewController?.present(navigationController, animated: true)
	}
}
