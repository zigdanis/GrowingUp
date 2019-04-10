//
//  PersonsListConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 08/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol PersonsListConfigurator {
	func configure(personsListController: PersonsListViewController)
}

final class PersonsListConfiguratorImplementation: PersonsListConfigurator {

	func configure(personsListController: PersonsListViewController) {
		let presenter = PersonsListPresenterImplementation()
		personsListController.presenter = presenter
	}
}
