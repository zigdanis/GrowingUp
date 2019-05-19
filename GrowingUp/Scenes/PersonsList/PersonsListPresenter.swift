//
//  PersonsListPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 08/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import Core

protocol PersonsListPresenter {
	func pageViewControllerScreen(atIndex index: Int) -> PageViewControllerViewable?
	func numberOfPages() -> Int
	func emptyPageIndex() -> Int
}

final class PersonsListPresenterImplementation: PersonsListPresenter {
	private var cachedScreens = [Int: PageViewControllerViewable]()
	private var persons = [Person]()
	private weak var view: PersonsListView?
	private let fetchPersonsUseCase: FetchPersonsUseCase
	private var defaultPage: Int = 0

	init(view: PersonsListView, displayPersonsUseCase: FetchPersonsUseCase) {
		self.view = view
		self.fetchPersonsUseCase = displayPersonsUseCase
		loadListOfPersons()
		subscribeToOpenPersonWithIdNotifications()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	private func loadListOfPersons() {
		fetchPersonsUseCase.fetchPersons { result in
			switch result {
			case .success(let value): self.persons = value
			case .failure(let error): Logging.logError(error)
			}
			self.cachedScreens.removeAll()
			self.view?.updateListOfScreens(defaultPage: self.defaultPage)
		}
	}

	private func subscribeToOpenPersonWithIdNotifications() {
		NotificationCenter.default.addObserver(self, selector: #selector(openPersonNotificationSent), name: Constants.openPersonNotification, object: nil)
	}

	@objc
	private func openPersonNotificationSent(notif: Notification) {
		let key = Constants.widgetPersonIndexKey
		guard let personIndex = notif.userInfo?[key] as? Int else { return }
		self.defaultPage = personIndex
		self.view?.updateListOfScreens(defaultPage: defaultPage)
	}

	func numberOfPages() -> Int {
		return min(persons.count + 1, 3)
	}

	func emptyPageIndex() -> Int {
		return persons.count
	}

	func pageViewControllerScreen(atIndex index: Int) -> PageViewControllerViewable? {
		guard index >= 0 else { return nil }
		guard index < 3 else { return nil }
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
			configurator.editPresenterDelegate = self
			let personVC = PersonOverviewViewController(configurator: configurator)
			cachedScreens[index] = personVC
			return personVC
		}
	}
}

extension PersonsListPresenterImplementation: EditPersonPresenterDelegate {

	func editPersonPresenter(_ presenter: EditPersonPresenter, didAdd person: Person) {
		Logging.logMessage("Added new Person")
		cachedScreens[persons.count] = nil
		persons.append(person)
		let scrollTo = persons.count - 1
		view?.updateListOfScreens(defaultPage: scrollTo)
		presenter.router.dismiss()
	}

	func editPersonPresenter(_ presenter: EditPersonPresenter, didEdit person: Person) {
		if let index = persons.firstIndex(where: { $0.id == person.id }) {
			persons.remove(at: index)
			persons.insert(person, at: index)
		}
	}

	func editPersonPresenter(_ presenter: EditPersonPresenter, didRemove person: Person) {
		Logging.logMessage("Removed Person")
		cachedScreens.removeAll()
		if let index = persons.firstIndex(of: person) {
			persons.remove(at: index)
			view?.updateListOfScreens(defaultPage: index)
		} else {
			Logging.logError(CoreError(message: "Couldn't find person in persons array when removed him/her"))
		}
		presenter.router.dismiss()
	}

	func editPersonPresenterCancel(presenter: EditPersonPresenter) {
		presenter.router.dismiss()
	}
}
