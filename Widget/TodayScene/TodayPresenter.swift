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
}

final class TodayPresenterImplementation: TodayPresenter {

	var maxRows: Int = 1

	func numberOfPersons() -> Int {
		return maxRows
	}
}
