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
}

final class TodayPresenterImplementation: TodayPresenter {

	var maxRows: Int = 1
	private var persons = [Person]()
	weak var view: TodayView?
//	private let fetchUseCase: FetchPersonsUseCaseImplementation

	init() {
//		let personsGateway = CachePersons
//		fetchUseCase = FetchPersonsUseCaseImplementation(personsGateway: <#T##PersonsGateway#>)
		loadPersons()
	}

	func numberOfPersons() -> Int {
		return min(maxRows, persons.count)
	}

	func configure(cell: PersonCellView, atIndex index: Int) {
		cell.displayName(name: "Hello")
		cell.displayAge(age: "a lot of years")
		
	}

	private func loadPersons() {

		view?.reloadTableData()
	}
}
