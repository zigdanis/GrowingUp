//
//  TextFieldCellPresenterSpy.swift
//  GrowingUpTests
//
//  Created by zigdanis on 20/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation
@testable import GrowingUp

final class TextFieldCellPresenterStub: TextFieldCellPresenter {
	
	var valuesForRow = [Int: String]()
	
	func configure(cell: TextFieldCellView, forRow row: Int) {
		
	}
	
}
