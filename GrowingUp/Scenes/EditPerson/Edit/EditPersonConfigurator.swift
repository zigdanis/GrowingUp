//
//  EditPersonConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import Core

protocol EditPersonConfigurator {
    func configure(editPersonViewController: EditPersonViewController)
}

class EditPersonConfiguratorImplementation: EditPersonConfigurator {

	private let person: Person
    private weak var editPersonPresenterDelegate: EditPersonPresenterDelegate?

	init(person: Person, editPersonPresenterDelegate: EditPersonPresenterDelegate?) {
		self.person = person
        self.editPersonPresenterDelegate = editPersonPresenterDelegate
    }

    func configure(editPersonViewController: EditPersonViewController) {
        let viewContext = CoreDataStackImplementation.sharedInstance.persistentContainer.viewContext
        let coreDataGateway = CoreDataPersonsGatewayImplementation(viewContext: viewContext)
		let taskManager = TaskManagerOnGCD()
		let personsGateway = CachePersonsGateway(coreDataGateway: coreDataGateway, taskManager: taskManager)
        let editPersonUseCase = EditPersonUseCaseImplementation(personsGateway: personsGateway)
		let removePersonUseCase = RemovePersonUseCaseImplementation(personsGateway: personsGateway)
        let router = EditPersonViewRouterImplementation(editPersonViewController: editPersonViewController)
		let imagesCellPresenter = ImagesCellPresenterImplementation()
		let nameCellPresenter = TextFieldCellPresenterImplementation()
		let dateCellPresenter = DateCellPresenterImplementation()
        let presenter = EditPersonPresenterImplementation(
			person: person,
			view: editPersonViewController,
			editPersonUseCase: editPersonUseCase,
			removePersonUseCase: removePersonUseCase,
			router: router,
			delegate: editPersonPresenterDelegate,
			imagesCellPresenter: imagesCellPresenter,
			nameCellPresenter: nameCellPresenter,
			dateCellsPresenter: dateCellPresenter
		)
		nameCellPresenter.textFieldObserver = presenter
        editPersonViewController.presenter = presenter
    }
}
