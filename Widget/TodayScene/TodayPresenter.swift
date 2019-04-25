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
	func numberOfPersons() -> Int
	var maxRows: Int { get set }
	func configure(cell: PersonCellView, atIndex index: Int)
	func loadPersons()
}

final class TodayPresenterImplementation: TodayPresenter {

	var maxRows: Int = 3
	private var persons = [Person]()
	weak var view: TodayView?
	private let fetchUseCase: FetchPersonsUseCase

	init() {
		let viewContext = CoreDataStackImplementation.sharedInstance.persistentContainer.viewContext
		let personsGateway = CoreDataPersonsGatewayImplementation(viewContext: viewContext)
		fetchUseCase = FetchPersonsUseCaseImplementation(personsGateway: personsGateway)
	}

	func numberOfPersons() -> Int {
		return min(maxRows, persons.count)
	}

	func configure(cell: PersonCellView, atIndex index: Int) {
		let person = persons[index]
		cell.displayName(name: person.name)
		cell.displayAge(for: person)

		guard let image = PersonImage(id: person.widgetPicId) else { return }
		ImagesCache.loadImageFromDisk(image: image) { result in
			switch result {
			case .success(let img):
				cell.displayWidgetPic(pic: img)
			case .failure(let error):
				Logging.logError(error)
			}
		}
	}

	func loadPersons() {
		fetchUseCase.fetchPersons { result in
			switch result {
			case .success(let persons):
				self.persons = persons
			case .failure(let error):
				Logging.logMessage("Failed to fetch Persons from CoreData")
				Logging.logError(error)
			}
			self.view?.reloadTableData()
		}
	}
}
