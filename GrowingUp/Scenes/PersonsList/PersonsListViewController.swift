//
//  PersonsListViewController.swift
//  GrowingUp
//
//  Created by zigdanis on 08/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import UIKit

protocol PageViewControllerViewable: UIViewController {
	var index: Int { get }
}

protocol PersonsListView: class {
	func updateListOfScreens()
}

final class PersonsListViewController: UIViewController, PersonsListView {

	@IBOutlet weak var pageIndicator: UIPageControl!
	private let pageController = UIPageViewController(transitionStyle: .scroll,
													  navigationOrientation: .horizontal,
													  options: nil)
	var presenter: PersonsListPresenter!
	var configurator: PersonsListConfigurator!

	init(configurator: PersonsListConfigurator) {
		self.configurator = configurator
		super.init(nibName: nil, bundle: nil)
	}

	@available(iOS, unavailable, message: "init(coder:) not implemented")
	required init(coder: NSCoder) {
		fatalError("init(coder:) not implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		configurator.configure(personsListController: self)
		view.backgroundColor = #colorLiteral(red: 0.9568627451, green: 0.9568627451, blue: 0.9568627451, alpha: 1)
		setupPageViewController()
		setupPageIndicator()
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
	}

	private func setupPageIndicator() {
		pageIndicator.pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.5)
		pageIndicator.currentPageIndicatorTintColor = UIColor.appColor
	}

	// MARK: - PersonsListView

	func updateListOfScreens() {
		guard let firstPVCScreen = presenter.pageViewControllerScreen(atIndex: 0) else { return }
		pageController.setViewControllers([firstPVCScreen], direction: .forward, animated: true, completion: nil)
	}

}

extension PersonsListViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

	private func indexFor(viewController: UIViewController?) -> Int {
		return (viewController as? PageViewControllerViewable)?.index ?? 0
	}

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		var index = indexFor(viewController: viewController)
		index += 1
		return presenter.pageViewControllerScreen(atIndex: index)
	}

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		var index = indexFor(viewController: viewController)
		index -= 1
		return presenter.pageViewControllerScreen(atIndex: index)
	}

	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		let currentVC = pageController.viewControllers?.first
		let currentIndex = indexFor(viewController: currentVC)
		pageIndicator.currentPage = currentIndex
	}

}
