//
//  TodayPresenter.swift
//  Widget
//
//  Created by zigdanis on 22/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
import Core

protocol TodayPresenter {
	var numberOfPersons: Int { get }
	func configure(panel: PersonView, atIndex index: Int)
	func loadPersons()
}

final class TodayPresenterImplementation: TodayPresenter {

	private var persons = [Person]()
	weak var view: TodayView?
	private let fetchUseCase: FetchPersonsUseCase
	var numberOfPersons: Int {
		persons.count
	}

	init() {
		let personsGateway = CoreDataPersonsGateway(coreDataStack: CoreDataStackImplementation.sharedInstance)
		fetchUseCase = FetchPersonsUseCaseImplementation(personsGateway: personsGateway)
	}

	func configure(panel: PersonView, atIndex index: Int) {
		let person = persons[index]
		panel.displayName(name: person.name)
		panel.displayAge(for: person)
		panel.displayWidgetPic(pic: nil)

		guard let image = PersonImage(id: person.widgetPicId) else { return }
		ImagesCache.loadImageFromDiskOrMemory(image: image) { result in
			switch result {
			case .success(let img):
				panel.displayWidgetPic(pic: img)
			case .failure(let error):
				panel.displayWidgetPic(pic: nil)
				Logging.logError(error)
			}
		}
	}

	func loadPersons() {
		fetchUseCase.fetchWidgetPersons { result in
			switch result {
			case .success(let persons):
				self.persons = persons
				self.view?.updateContent()
			case .failure(let error):
				Logging.logMessage("Failed to fetch Persons from CoreData")
				Logging.logError(error)
			}
		}
	}
}
