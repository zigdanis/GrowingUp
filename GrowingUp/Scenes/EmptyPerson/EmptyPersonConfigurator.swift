//
//  EmptyPersonConfigurator.swift
//  GrowingUp
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol EmptyPersonConfigurator {
	func configure(emptyPersonController: EmptyPersonViewController)
}

final class EmptyPersonConfiguratorImplementation: EmptyPersonConfigurator {
	let index: Int

	init(index: Int) {
		self.index = index
	}

	func configure(emptyPersonController: EmptyPersonViewController) {
		let presenter = EmptyPersonPresenterImplementation()
		emptyPersonController.presenter = presenter
		emptyPersonController.index = index
	}
}
