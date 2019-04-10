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
//	private var cachedScreens = [Int: PersonOverviewView]()
//	private var persons = [ Person.create(), Person.create(), Person.create() ]
//
	func pageViewControllerScreen(atIndex index: Int) -> PageViewControllerViewable? {
		return nil
//		guard let firstPerson = persons.first else { return }
//		let personVC = PersonOverviewViewController(person: firstPerson, index: 0)
//		cachedScreens[0] = personVC
	}

//private func controllerForIndex(_ index: Int) -> UIViewController? {
//	guard index >= 0 else { return nil }
//	guard index < persons.count else { return nil }
//	let person = persons[index]
//	if let cached = cachedScreens[index] {
//		return cached
//	} else {
//		let personVC = PersonOverviewViewController(person: person, index: index)
//		cachedScreens[index] = personVC
//		return personVC
//	}
//}
}
