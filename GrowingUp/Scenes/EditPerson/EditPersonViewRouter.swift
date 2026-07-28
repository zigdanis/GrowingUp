//
//  EditPersonViewRouter.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

protocol EditPersonViewRouter {
	func dismiss()
}

class EditPersonViewRouterImplementation: EditPersonViewRouter {

	private weak var editPersonViewController: EditPersonViewController?

	init(editPersonViewController: EditPersonViewController) {
		self.editPersonViewController = editPersonViewController
	}

	func dismiss() {
		editPersonViewController?.dismiss(animated: true)
	}
}
