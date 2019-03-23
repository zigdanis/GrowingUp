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
        return true
    }

    private func setupMainViewController() {
        window = UIWindow(frame: UIScreen.main.bounds)
        let configurator = AddPersonConfiguratorImplementation(addPersonPresenterDelegate: self)
//		let mainVC = UIViewController()
        let mainVC = AddPersonViewController(configurator: configurator)
        let navigationVC = UINavigationController(rootViewController: mainVC)
        window?.rootViewController = navigationVC
        window?.makeKeyAndVisible()
    }

    private func setupNavigationControllerAppearence() {
        window?.tintColor = .appColor
    }
}

extension AppDelegate: AddPersonPresenterDelegate {
    func addPersonPresenter(_ presenter: AddPersonPresenter, didAdd person: Person) {
        print("Did Add Person")
    }

    func addPersonPresenterCancel(presenter: AddPersonPresenter) {
        print("Cancel tapped")
    }

}
