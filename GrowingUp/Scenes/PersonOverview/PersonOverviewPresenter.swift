//
//  PersonOverviewPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 09/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import Core

protocol PersonOverviewPresenter {
	func loadPerson()
	func showEditPerson()
}

final class PersonOverviewPresenterImplementation: PersonOverviewPresenter {

	weak var view: PersonOverviewView?
	weak var personPresenterDelegate: EditPersonPresenterDelegate?
	private var person: Person
	private let router: PersonOverviewRouter
	private var timer: Timer?

	init(person: Person, personOverviewView: PersonOverviewView, router: PersonOverviewRouter) {
		self.person = person
		self.view = personOverviewView
		self.router = router
	}

	func loadPerson() {
		view?.displayPersonName(name: person.name)
		let personAppPic = PersonImage(id: person.appPicId, uiImage: nil)
		view?.displayPersonAppImage(image: personAppPic)
		scheduleAgeTicker()
	}

	func showEditPerson() {
		router.showEdit(for: person, presenterDelegate: self)
	}

	private func scheduleAgeTicker() {
		timer?.invalidate()
		showAge()
		timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
			self.showAge()
		}
	}

	private func showAge() {
		let age = AgeCalculator.ageString(for: person.dateComponents)
		view?.displayPersonAge(age: age)
	}
}

extension PersonOverviewPresenterImplementation: EditPersonPresenterDelegate {
	func editPersonPresenter(_ presenter: EditPersonPresenter, didAdd person: Person) {}

	func editPersonPresenter(_ presenter: EditPersonPresenter, didEdit person: Person) {
		self.person = person
		loadPerson()
		presenter.router.dismiss()
	}

	func editPersonPresenter(_ presenter: EditPersonPresenter, didRemove person: Person) {
		personPresenterDelegate?.editPersonPresenter(presenter, didRemove: person)
	}

	func editPersonPresenterCancel(presenter: EditPersonPresenter) {
		presenter.router.dismiss()
	}
}
