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
	func displayPersonAppImage(image: PersonImage?)
	func displayPersonAge(age: String)
	func displayPersonOnWidgetState(onWidget: Bool)
}

final class PersonOverviewViewController: UIViewController, PersonOverviewView {

	@IBOutlet weak var appImage: UIImageView!
	@IBOutlet weak var personName: UILabel!
	@IBOutlet weak var personAge: UILabel!
	@IBOutlet weak var noPicPlaceholder: UILabel!
	@IBOutlet weak var darkHoverView: UIView!
	@IBOutlet weak var editPersonButton: UIButton!

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
		setupTapGesture()
		setupPersonNameTopConstraint()
		setupNoPicPlaceholder()
	}

	private func setupPersonNameTopConstraint() {
		let top = personName.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
		top.isActive = true
	}

	private func setupNoPicPlaceholder() {
		noPicPlaceholder.text = "🤷"
	}

	private func setupTapGesture() {
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(screenPressed))
		view.addGestureRecognizer(tapGesture)
	}

	@objc
	private func screenPressed() {
		presenter.showEditPerson()
	}

	@IBAction func editPersonTouched() {
		presenter.showEditPerson()
	}

	// MARK: - PersonOverviewView

	func displayPersonName(name: String) {
		personName.text = name
	}

	func displayPersonAppImage(image: PersonImage?) {
		noPicPlaceholder.isHidden = image != nil
		darkHoverView.alpha = image != nil ? 0.15 : 0.5
		guard let image = image else { return }
		ImagesCache.loadImageFromDiskOrMemory(image: image) { result in
			switch result {
			case.success(let img):
				self.appImage.image = img
			case .failure(let error):
				Logging.logError(error)
			}
		}
	}

	func displayPersonAge(age: String) {
		personAge.text = age
	}

	func displayPersonOnWidgetState(onWidget: Bool) {
		let img = onWidget ? R.image.personCrowned() : R.image.personSettings()
		editPersonButton.setImage(img, for: .normal)
	}
}
