//
//  PersonsListPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 08/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol PersonsListPresenter {
	func pageViewControllerScreen(atIndex index: Int) -> PageViewControllerViewable?
	func numberOfPages() -> Int
}

final class PersonsListPresenterImplementation: PersonsListPresenter {
	private var cachedScreens = [Int: PageViewControllerViewable]()
	private var persons = [Person]()
	private weak var view: PersonsListView?
	private let displayPersonsUseCase: DisplayPersonsUseCase

	init(view: PersonsListView, displayPersonsUseCase: DisplayPersonsUseCase) {
		self.view = view
		self.displayPersonsUseCase = displayPersonsUseCase
		loadListOfPersons()
	}

	private func loadListOfPersons() {
		displayPersonsUseCase.displayPersons { result in
			switch result {
			case .success(let value): self.persons = value
			case .failure(let error): Logging.log(error)
			}
			self.view?.updateListOfScreens()
		}
	}

	func numberOfPages() -> Int {
		return persons.count + 1
	}

	func pageViewControllerScreen(atIndex index: Int) -> PageViewControllerViewable? {
		guard index >= 0 else { return nil }
		guard index <= persons.count else { return nil }
		if let cached = cachedScreens[index] {
			return cached
		} else if index == persons.count {
			let configurator = EmptyPersonConfiguratorImplementation(index: index, addPersonPresenterDelegate: self)
			let emptyVC = EmptyPersonViewController(configurator: configurator)
			cachedScreens[index] = emptyVC
			return emptyVC
		} else {
			let person = persons[index]
			let configurator = PersonOverviewConfiguratorImplementation(index: index, person: person)
			let personVC = PersonOverviewViewController(configurator: configurator)
			cachedScreens[index] = personVC
			return personVC
		}
	}
}

extension PersonsListPresenterImplementation: EditPersonPresenterDelegate {

	func editPersonPresenter(_ presenter: EditPersonPresenter, didAdd person: Person) {
		cachedScreens[persons.count] = nil
		persons.append(person)
		view?.updateListOfScreens()
		presenter.router.dismiss()
	}

	func editPersonPresenterCancel(presenter: EditPersonPresenter) {
		presenter.router.dismiss()
	}
}
