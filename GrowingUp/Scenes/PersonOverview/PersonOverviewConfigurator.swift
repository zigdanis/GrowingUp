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
	let person: Person

	init(index: Int, person: Person) {
		self.index = index
		self.person = person
	}

	func configure(personOverviewController: PersonOverviewViewController) {
		let presenter = PersonOverviewPresenterImplementation(person: person)
		personOverviewController.presenter = presenter
		personOverviewController.index = index
	}
}
