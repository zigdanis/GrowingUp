//
//  PersonOverviewViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 09/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit
import Core

protocol PersonOverviewView: PageViewControllerViewable {
	func displayPersonName(name: String)
	func displayPersonAppImage(image: PersonImage)
	func displayPersonAge(age: String)
}

final class PersonOverviewViewController: UIViewController, PersonOverviewView {

	@IBOutlet weak var appImage: UIImageView!
	@IBOutlet weak var personName: UILabel!
	@IBOutlet weak var personAge: UILabel!

	var index: Int = 0
	var presenter: PersonOverviewPresenter!
	var configurator: PersonOverviewConfigurator!

	init(configurator: PersonOverviewConfigurator) {
		self.configurator = configurator
		super.init(nibName: nil, bundle: nil)
	}

	@available(iOS, unavailable, message: "Object of this class should use init()")
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		configurator.configure(personOverviewController: self)
		presenter.loadPerson()
	}

	@IBAction func editPersonTouched() {
		presenter.showEditPerson()
	}

	// MARK: - PersonOverviewView

	func displayPersonName(name: String) {
		personName.text = name
	}

	func displayPersonAppImage(image: PersonImage) {
		ImagesCache.loadImageFromDisk(image: image) { result in
			switch result {
			case.success(let img):
				self.appImage.image = img
			case .failure(let error):
				Logging.log(error)
			}
		}
	}

	func displayPersonAge(age: String) {
		personAge.text = age
	}
}
