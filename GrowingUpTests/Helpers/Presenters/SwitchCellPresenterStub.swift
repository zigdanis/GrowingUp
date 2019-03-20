//
//  SwitchCellPresenterStub.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

final class SwitchCellPresenterStub: SwitchCellPresenter {
	
	func configure(cell: SwitchCellView, forRow row: Int) {
	}
	
	var valuesForRow = [Int: Bool]()
	
	func updatedComponents() -> AddPersonDateComponents {
		return AddPersonDateComponents()
	}
	
	
}
