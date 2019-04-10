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
		let viewContext = CoreDataStackImplementation.sharedInstance.persistentContainer.viewContext
		let coreDataGateway = CoreDataPersonsGatewayImplementation(viewContext: viewContext)
		let taskManager = TaskManagerOnGCD()
		let personsGateway = CachePersonsGateway(coreDataGateway: coreDataGateway, taskManager: taskManager)
		let displayPersonsUseCase = DisplayPersonsUseCaseImplementation(personsGateway: personsGateway)
		let presenter = PersonsListPresenterImplementation(view: personsListController, displayPersonsUseCase: displayPersonsUseCase)
		personsListController.presenter = presenter
	}
}
