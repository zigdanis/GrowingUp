//
//  PersonOverviewConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 09/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol PersonOverviewConfigurator {
	func configure(personOverviewController: PersonOverviewViewController)
}

final class PersonOverviewConfiguratorImplementation: PersonOverviewConfigurator {

	let index: Int

	init(index: Int) {
		self.index = index
	}

	func configure(personOverviewController: PersonOverviewViewController) {
		let presenter = PersonOverviewPresenterImplementation()
		personOverviewController.presenter = presenter
		personOverviewController.index = index
	}
}
