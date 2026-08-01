//
//  EditPersonConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Core
import Foundation

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
		let coreDataGateway = CoreDataPersonsGateway(coreDataStack: CoreDataStackImplementation.sharedInstance)
		let personsGateway = CachePersonsGateway(coreDataGateway: coreDataGateway, imageStore: DiskImageStore())
		let editPersonUseCase = EditPersonUseCaseImplementation(personsGateway: personsGateway)
		let removePersonUseCase = RemovePersonUseCaseImplementation(personsGateway: personsGateway)
		let router = EditPersonViewRouterImplementation(editPersonViewController: editPersonViewController)
		let imagesCellPresenter = ImagesCellPresenterImplementation()
		let nameCellPresenter = TextFieldCellPresenterImplementation()
		let dateCellPresenter = DateCellPresenterImplementation()
		let toggleCellPresenter = ToggleCellPresenterImplementation()
		let presenter = EditPersonPresenterImplementation(
			person: person,
			view: editPersonViewController,
			editPersonUseCase: editPersonUseCase,
			removePersonUseCase: removePersonUseCase,
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
