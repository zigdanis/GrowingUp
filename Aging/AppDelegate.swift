//
//  AppDelegate.swift
//  Aging
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
        let startVC = SettingsViewController()
        let navigationVC = UINavigationController(rootViewController: startVC)
        window?.rootViewController = navigationVC
        window?.makeKeyAndVisible()
    }
   
    private func setupNavigationControllerAppearence() {
        window?.tintColor = AppColor
    }
}

