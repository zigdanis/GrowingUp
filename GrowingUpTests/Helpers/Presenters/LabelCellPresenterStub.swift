//
//  LabelCellPresenterSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

final class LabelCellPresenterStub: DateCellPresenter {
	
	var valuesForRow = [Int : Date]()
	
	func configure(cell: DateCellView, forRow row: Int) {

	}
	
}
