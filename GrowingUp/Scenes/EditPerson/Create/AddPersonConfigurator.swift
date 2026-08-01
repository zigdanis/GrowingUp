//
//  AddPersonConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 16/04/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Core
import Foundation

class AddPersonConfigurator: EditPersonConfigurator {

	private weak var editPersonPresenterDelegate: EditPersonPresenterDelegate?

	init(editPersonPresenterDelegate: EditPersonPresenterDelegate?) {
		self.editPersonPresenterDelegate = editPersonPresenterDelegate
	}

	func configure(editPersonViewController: EditPersonViewController) {
		let coreDataGateway = CoreDataPersonsGateway(coreDataStack: CoreDataStackImplementation.sharedInstance)
		let personsGateway = CachePersonsGateway(coreDataGateway: coreDataGateway, imageStore: DiskImageStore())
		let fetchWidgetPersonsUseCase = FetchPersonsUseCaseImplementation(personsGateway: coreDataGateway)
		let addPersonUseCase = AddPersonUseCaseImplementation(personsGateway: personsGateway)
		let router = EditPersonViewRouterImplementation(editPersonViewController: editPersonViewController)
		let imagesCellPresenter = ImagesCellPresenterImplementation()
		let nameCellPresenter = TextFieldCellPresenterImplementation()
		let dateCellPresenter = DateCellPresenterImplementation()
		let toggleCellPresenter = ToggleCellPresenterImplementation()
		let presenter = AddPersonPresenter(
			view: editPersonViewController,
			addPersonUseCase: addPersonUseCase,
			fetchWidgetPersonsUseCase: fetchWidgetPersonsUseCase,
			router: router,
			delegate: editPersonPresenterDelegate,
			imagesCellPresenter: imagesCellPresenter,
			nameCellPresenter: nameCellPresenter,
			dateCellsPresenter: dateCellPresenter,
			toggleCellPresenter: toggleCellPresenter
		)
		nameCellPresenter.textFieldObserver = presenter
		editPersonViewController.presenter = presenter
		toggleCellPresenter.toggleDelegate = presenter
		dateCellPresenter.dateDelegate = presenter
	}
}
