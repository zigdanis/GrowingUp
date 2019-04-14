//
//  PersonOverviewPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 09/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol PersonOverviewPresenter {
	func loadPerson()
}

final class PersonOverviewPresenterImplementation: PersonOverviewPresenter {

	let person: Person
	weak var view: PersonOverviewView?

	init(person: Person, personOverviewView: PersonOverviewView) {
		self.person = person
		self.view = personOverviewView
	}

	func loadPerson() {
		view?.displayPersonName(name: person.name)
		let personAppPic = PersonImage(id: person.appPicId, uiImage: nil)
		view?.displayPersonAppImage(image: personAppPic)
	}

}
