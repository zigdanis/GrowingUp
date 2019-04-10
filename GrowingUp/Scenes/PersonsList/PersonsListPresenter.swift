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
}

final class PersonsListPresenterImplementation: PersonsListPresenter {
	private var cachedScreens = [Int: PersonOverviewView]()
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
			// TODO: - Add Logging Errors
			case .failure(let error): print("Error occured = \(error.message)")
			}
			self.view?.updateListOfScreens()
		}
	}

	func pageViewControllerScreen(atIndex index: Int) -> PageViewControllerViewable? {
		guard index >= 0 else { return nil }
		guard index < persons.count else { return nil }
		let person = persons[index]
		if let cached = cachedScreens[index] {
			return cached
		} else {
			let personVC = PersonOverviewViewController(person: person, index: index)
			cachedScreens[index] = personVC
			return personVC
		}
	}
}
