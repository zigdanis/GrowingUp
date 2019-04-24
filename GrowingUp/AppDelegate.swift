//
//  AppDelegate.swift
//  GrowingUp
//
//  Created by zigdanis on 14/12/2018.
//  Copyright © 2018 zigdanis. All rights reserved.
//

import UIKit
import Core

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupMainViewController()
        setupNavigationControllerAppearence()
		setupFileProtectionLevelForSharedContainer()
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

	private func setupFileProtectionLevelForSharedContainer() {
		let pathURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupId)
		guard let path = pathURL?.path else { return }
		do {
			let noneAtts: [FileAttributeKey: Any] = [
				FileAttributeKey.protectionKey: FileProtectionType.none
			]
			try FileManager.default.setAttributes(noneAtts, ofItemAtPath: path)
		} catch {
			let error = CoreError(message: "Failed to set attributes for shared container URL. Error = \(error.localizedDescription)")
			Logging.log(error)
		}
	}

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
		guard let appStr = options[.sourceApplication] as? String else { return true }
		guard appStr == Constants.widgetBundle else { return true }
		let components = URLComponents(string: url.absoluteString)
		let indexComponent = components?.queryItems?
			.first(where: { $0.name == Constants.widgetPersonIndexKey })
		let personIndexStr = indexComponent?.value ?? ""
		let personIndex = Int(personIndexStr) ?? 0
		print("Open URL with personIndex = \(personIndex)")
		NotificationCenter.default.post(name: Constants.openPersonNotification, object: nil, userInfo: [Constants.widgetPersonIndexKey: personIndex])
		return true
	}

}
