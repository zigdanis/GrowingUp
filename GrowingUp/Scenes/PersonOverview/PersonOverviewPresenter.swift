//
//  PersonOverviewPresenter.swift
//  GrowingUp
//
//  Created by zigdanis on 09/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol PersonOverviewPresenter {

}

final class PersonOverviewPresenterImplementation: PersonOverviewPresenter {

	let person: Person

	init(person: Person) {
		self.person = person
	}

}
