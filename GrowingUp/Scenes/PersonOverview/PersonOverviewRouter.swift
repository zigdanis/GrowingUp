//
//  PersonOverviewRouter.swift
//  GrowingUp
//
//  Created by zigdanis on 09/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Core
import Foundation
import UIKit

protocol PersonOverviewRouter {
	func showEdit(for person: Person, presenterDelegate: EditPersonPresenterDelegate?)
}

final class PersonOverviewRouterImplementation: PersonOverviewRouter {

	private weak var personOverviewViewController: PersonOverviewViewController?

	init(personOverviewViewController: PersonOverviewViewController) {
		self.personOverviewViewController = personOverviewViewController
	}

	func showEdit(for person: Person, presenterDelegate: EditPersonPresenterDelegate?) {
		let configurator = EditPersonConfiguratorImplementation(
			person: person, editPersonPresenterDelegate: presenterDelegate)
		let viewController = EditPersonViewController(configurator: configurator)
		let navigationController = UINavigationController(rootViewController: viewController)
		personOverviewViewController?.present(navigationController, animated: true)
	}
}
