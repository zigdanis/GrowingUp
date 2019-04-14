//
//  EditPersonConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol EditPersonConfigurator {
    func configure(addPersonViewController: EditPersonViewController)
}

class EditPersonConfiguratorImplementation: EditPersonConfigurator {

    weak var addPersonPresenterDelegate: EditPersonPresenterDelegate?

    init(addPersonPresenterDelegate: EditPersonPresenterDelegate?) {
        self.addPersonPresenterDelegate = addPersonPresenterDelegate
    }

    func configure(addPersonViewController: EditPersonViewController) {
        let viewContext = CoreDataStackImplementation.sharedInstance.persistentContainer.viewContext
        let coreDataGateway = CoreDataPersonsGatewayImplementation(viewContext: viewContext)
		let taskManager = TaskManagerOnGCD()
		let personsGateway = CachePersonsGateway(coreDataGateway: coreDataGateway, taskManager: taskManager)
        let addPersonUseCase = AddPersonUseCaseImplementation(personsGateway: personsGateway)
        let router = EditPersonViewRouterImplementation(addPersonViewController: addPersonViewController)
		let imagesCellPresenter = ImagesCellPresenterImplementation()
		let nameCellPresenter = TextFieldCellPresenterImplementation()
		let dateCellPresenter = DateCellPresenterImplementation()
		let dateComponentsPresenter = SwitchCellPresenterImplementation()
        let presenter = EditPersonPresenterImplementation(
			view: addPersonViewController,
			addPersonUseCase: addPersonUseCase,
			router: router,
			delegate: addPersonPresenterDelegate,
			imagesCellPresenter: imagesCellPresenter,
			nameCellPresenter: nameCellPresenter,
			dateCellsPresenter: dateCellPresenter,
			dateComponentsCellsPresenter: dateComponentsPresenter
		)
		nameCellPresenter.textFieldObserver = presenter
        addPersonViewController.presenter = presenter
    }
}
