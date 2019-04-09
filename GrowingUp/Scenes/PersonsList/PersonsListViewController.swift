//
//  PersonsListViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 08/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

extension Person {
	static func create() -> Person {
		return Person(id: UUID(), name: "SSS", birthday: Date())
	}
}

final class PersonsListViewController: UIViewController {

	@IBOutlet weak var pageIndicator: UIPageControl!
	private let pageController = UIPageViewController(transitionStyle: .scroll,
													  navigationOrientation: .horizontal,
													  options: nil)
	private var currentIndex = 0
	private var cachedScreens = [Int: PersonOverviewViewController]()
	private var persons = [ Person.create(), Person.create(), Person.create() ]

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

		guard let firstPerson = persons.first else { return }
		let personVC = PersonOverviewViewController(person: firstPerson, index: 0)
		cachedScreens[0] = personVC
		pageController.setViewControllers([personVC], direction: .forward, animated: true, completion: nil)
	}

}

extension PersonsListViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

	private func indexFor(viewController: UIViewController?) -> Int {
		guard let personVC = viewController as? PersonOverviewViewController else { return 0 }
		return personVC.index
	}

	private func controllerForIndex(_ index: Int) -> UIViewController? {
		guard index >= 0 else { return nil }
		guard index < persons.count else { return nil }
		let person = persons[index]
		if let cached = cachedScreens[index] {
			return cached
		} else {
			let personVC = PersonOverviewViewController(person: person, index: index)
			cachedScreens[index] = personVC
			return personVC
		}
	}

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		var index = indexFor(viewController: viewController)
		index += 1
		return controllerForIndex(index)
	}

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		var index = indexFor(viewController: viewController)
		index -= 1
		return controllerForIndex(index)
	}

	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		let currentVC = pageController.viewControllers?.first
		currentIndex = indexFor(viewController: currentVC)
	}

}
