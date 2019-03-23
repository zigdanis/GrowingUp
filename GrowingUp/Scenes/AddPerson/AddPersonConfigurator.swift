//
//  AddPersonConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol AddPersonConfigurator {
    func configure(addPersonViewController: AddPersonViewController)
}

class AddPersonConfiguratorImplementation: AddPersonConfigurator {

    weak var addPersonPresenterDelegate: AddPersonPresenterDelegate?

    init(addPersonPresenterDelegate: AddPersonPresenterDelegate?) {
        self.addPersonPresenterDelegate = addPersonPresenterDelegate
    }

    func configure(addPersonViewController: AddPersonViewController) {
        let viewContext = CoreDataStackImplementation.sharedInstance.persistentContainer.viewContext
        let personsGateway = CoreDataPersonsGateway(viewContext: viewContext)
        let addPersonUseCase = AddPersonUseCaseImplementation(personsGateway: personsGateway)
        let router = AddPersonViewRouterImplementation(addPersonViewController: addPersonViewController)
		let imagesCellPresenter = ImagesCellPresenterImplementation()
		let nameCellPresenter = TextFieldCellPresenterImplementation()
		let dateCellPresenter = DateCellPresenterImplementation()
		let dateComponentsPresenter = SwitchCellPresenterImplementation()
        let presenter = AddPersonPresenterImplementation(
			view: addPersonViewController,
			addPersonUseCase: addPersonUseCase,
			router: router,
			delegate: addPersonPresenterDelegate,
			imagesCellPresenter: imagesCellPresenter,
			nameCellPresenter: nameCellPresenter,
			dateCellsPresenter: dateCellPresenter,
			dateComponentsCellsPresenter: dateComponentsPresenter
		)
        addPersonViewController.presenter = presenter
    }
}
