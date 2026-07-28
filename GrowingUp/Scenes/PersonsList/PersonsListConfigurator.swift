//
//  PersonsListConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 08/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Core
import Foundation

protocol PersonsListConfigurator {
	func configure(personsListController: PersonsListViewController)
}

final class PersonsListConfiguratorImplementation: PersonsListConfigurator {

	func configure(personsListController: PersonsListViewController) {
		let coreDataGateway = CoreDataPersonsGateway(coreDataStack: CoreDataStackImplementation.sharedInstance)
		let taskManager = TaskManagerOnGCD()
		let personsGateway = CachePersonsGateway(coreDataGateway: coreDataGateway, taskManager: taskManager)
		let fetchPersonsUseCase = FetchPersonsUseCaseImplementation(personsGateway: personsGateway)
		let presenter = PersonsListPresenterImplementation(
			view: personsListController, displayPersonsUseCase: fetchPersonsUseCase)
		personsListController.presenter = presenter
	}
}
