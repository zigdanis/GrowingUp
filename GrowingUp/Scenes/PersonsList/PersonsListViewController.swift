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
	var currentStatusBarStyle: UIStatusBarStyle = .lightContent

	init(configurator: PersonsListConfigurator) {
		self.configurator = configurator
		super.init(nibName: nil, bundle: nil)
	}

	@available(iOS, unavailable, message: "init(coder:) not implemented")
	required init(coder: NSCoder) {
		fatalError("init(coder:) not implemented")
	}

	override var preferredStatusBarStyle: UIStatusBarStyle {
		return currentStatusBarStyle
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		configurator.configure(personsListController: self)
		setupPageViewController()
		setupPageIndicator()
	}

	private func setupPageViewController() {
		pageController.delegate = self
		pageController.dataSource = self
		addChild(pageController)
		pageController.view.translatesAutoresizingMaskIntoConstraints = false
		view.insertSubview(pageController.view, at: 0)
		pageController.didMove(toParent: self)
		let consts = [
			pageController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			pageController.view.topAnchor.constraint(equalTo: view.topAnchor),
			view.trailingAnchor.constraint(equalTo: pageController.view.trailingAnchor),
			view.bottomAnchor.constraint(equalTo: pageController.view.bottomAnchor)
		]
		NSLayoutConstraint.activate(consts)

		pageController.view.backgroundColor = #colorLiteral(red: 0.8470588235, green: 0.8470588235, blue: 0.8470588235, alpha: 1)
	}

	private func setupPageIndicator() {
		pageIndicator.pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.5)
		pageIndicator.currentPageIndicatorTintColor = UIColor.appColor
		pageIndicator.pageIndicatorTintColor = UIColor.lightGray
	}

	// MARK: - PersonsListView

	func updateListOfScreens() {
		let total = presenter.numberOfPages()
		pageIndicator.numberOfPages = total
		let index = total == 3 ? 2 : max(total - 2, 0)
		pageIndicator.currentPage = index
		guard let lastScreen = presenter.pageViewControllerScreen(atIndex: index) else { return }
		pageController.setViewControllers([lastScreen], direction: .forward, animated: false, completion: nil)
		updateStatusBarAppearence(forIndex: index)
	}

	private func updateStatusBarAppearence(forIndex index: Int) {
		if (index == presenter.numberOfPages() - 1) && (index != 2) {
			currentStatusBarStyle = .default
		} else {
			currentStatusBarStyle = .lightContent
		}
		setNeedsStatusBarAppearanceUpdate()
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
		updateStatusBarAppearence(forIndex: currentIndex)
	}

}
