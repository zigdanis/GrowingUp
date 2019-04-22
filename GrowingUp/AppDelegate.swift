//
//  AppDelegate.swift
//  GrowingUp
//
//  Created by zigdanis on 14/12/2018.
//  Copyright © 2018 zigdanis. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupMainViewController()
        setupNavigationControllerAppearence()
		#if DEBUG
		let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
		print("Documents URL = \(urls)")
		#endif
		return true
    }

    private func setupMainViewController() {
        window = UIWindow(frame: UIScreen.main.bounds)
		let configurator = PersonsListConfiguratorImplementation()
		let mainVC = PersonsListViewController(configurator: configurator)
        window?.rootViewController = mainVC
        window?.makeKeyAndVisible()
    }

    private func setupNavigationControllerAppearence() {
        window?.tintColor = .appColor
    }
}
