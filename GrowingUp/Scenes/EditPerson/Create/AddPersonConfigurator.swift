//
//  AddPersonConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 16/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

class AddPersonConfigurator: EditPersonConfigurator {

	private weak var editPersonPresenterDelegate: EditPersonPresenterDelegate?

	init(editPersonPresenterDelegate: EditPersonPresenterDelegate?) {
		self.editPersonPresenterDelegate = editPersonPresenterDelegate
	}

	func configure(editPersonViewController: EditPersonViewController) {
		let viewContext = CoreDataStackImplementation.sharedInstance.persistentContainer.viewContext
		let coreDataGateway = CoreDataPersonsGatewayImplementation(viewContext: viewContext)
		let taskManager = TaskManagerOnGCD()
		let personsGateway = CachePersonsGateway(coreDataGateway: coreDataGateway, taskManager: taskManager)
		let addPersonUseCase = AddPersonUseCaseImplementation(personsGateway: personsGateway)
		let router = EditPersonViewRouterImplementation(editPersonViewController: editPersonViewController)
		let imagesCellPresenter = ImagesCellPresenterImplementation()
		let nameCellPresenter = TextFieldCellPresenterImplementation()
		let dateCellPresenter = DateCellPresenterImplementation()
		let dateComponentsPresenter = SwitchCellPresenterImplementation()
		let presenter = AddPersonPresenter(
			view: editPersonViewController,
			addPersonUseCase: addPersonUseCase,
			router: router,
			delegate: editPersonPresenterDelegate,
			imagesCellPresenter: imagesCellPresenter,
			nameCellPresenter: nameCellPresenter,
			dateCellsPresenter: dateCellPresenter,
			dateComponentsCellsPresenter: dateComponentsPresenter
		)
		nameCellPresenter.textFieldObserver = presenter
		editPersonViewController.presenter = presenter
	}
}
