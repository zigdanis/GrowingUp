//
//  PersonsListViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 08/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol PersonPersonalView: class {
	init(person: Person)
	var index: Int { get }
}

final class PersonsListViewController: UIViewController {

	@IBOutlet weak var pageIndicator: UIPageControl!
	private let pageController = UIPageViewController(transitionStyle: .scroll,
													  navigationOrientation: .horizontal,
													  options: nil)
	private var currentIndex = 0
	private var cachedScreens = [Int: PersonPersonalView]()

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = #colorLiteral(red: 0.9568627451, green: 0.9568627451, blue: 0.9568627451, alpha: 1)
		setupPageViewController()
	}

	private func setupPageViewController() {
		pageController.delegate = self
		pageController.dataSource = self
		addChild(pageController)
		view.insertSubview(pageController.view, at: 0)
		pageController.didMove(toParent: self)
		let consts = [
			pageController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			pageController.view.topAnchor.constraint(equalTo: view.topAnchor),
			view.trailingAnchor.constraint(equalTo: pageController.view.trailingAnchor),
			view.bottomAnchor.constraint(equalTo: pageController.view.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)
//		let person = Person.init(id: UUID(), name: "String", birthday: Date())
//		let personVC = PersonPersonalView(person: person)
//		cachedScreens[0] = personVC
//		pageController.setViewControllers([personVC], direction: .forward, animated: true, completion: nil)
		pageController.setViewControllers([UIViewController()], direction: .forward, animated: true, completion: nil)
	}

}

extension PersonsListViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

	private func indexForController(_ vc: UIViewController?) -> Int {
		guard let tutScreen = vc as? PersonPersonalView else { return 0 }
		return tutScreen.index
	}

	private func controllerForIndex(_ index: Int) -> UIViewController? {
		return nil
//		guard let screen = TutorialScreen(rawValue: index) else { return nil }
//		if let cached = cachedScreens[screen] {
//			return cached
//		} else {
//			let tutVC = TutorialViewController(screen: screen)
//			tutVC.bottomPanelHeight = bottomPanel.bounds.height
//			cachedScreens[screen] = tutVC
//			return tutVC
//		}
	}

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		var index = indexForController(viewController)
		index += 1
		return controllerForIndex(index)
	}

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		var index = indexForController(viewController)
		index -= 1
		return controllerForIndex(index)
	}

	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		let currentVC = pageController.viewControllers?.first
		currentIndex = indexForController(currentVC)
	}

}
