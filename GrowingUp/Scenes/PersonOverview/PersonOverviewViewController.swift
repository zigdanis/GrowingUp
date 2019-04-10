//
//  PersonOverviewViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 09/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol PersonOverviewView: PageViewControllerViewable {
	var person: Person { get }
}

final class PersonOverviewViewController: UIViewController, PersonOverviewView {

	var person: Person
	var index: Int
	var presenter: PersonOverviewPresenter!
	var configurator: PersonOverviewConfigurator!

	init(person: Person, index: Int) {
		self.person = person
		self.index = index
		super.init(nibName: nil, bundle: nil)
	}

	@available(iOS, unavailable, message: "Object of this class should use init()")
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		configurator.configure(personOverviewController: self)
	}
}
