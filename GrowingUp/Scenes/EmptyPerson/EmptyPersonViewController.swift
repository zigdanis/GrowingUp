//
//  EmptyPersonViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 11/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol EmptyPersonView {

}

final class EmptyPersonViewController: UIViewController, EmptyPersonView, PageViewControllerViewable {

	var index: Int = 0
	var presenter: EmptyPersonPresenter!
	var configurator: EmptyPersonConfigurator!

	init(configurator: EmptyPersonConfigurator) {
		self.configurator = configurator
		super.init(nibName: nil, bundle: nil)
	}

	@available(iOS, unavailable, message: "Object of this class should use init()")
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		configurator.configure(emptyPersonController: self)
	}
}
