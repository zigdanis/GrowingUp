//
//  AppDelegate.swift
//  GrowingUp
//
//  Created by zigdanis on 14/12/2018.
//  Copyright © 2018 zigdanis. All rights reserved.
//

import Core
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(
		_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
	) -> Bool {
		setupMainViewController()
		setupNavigationControllerAppearence()
		setupFileProtectionLevelForSharedContainer()
		Logging.setup()
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
			let error = CoreError(
				message: "Failed to set attributes for shared container URL. Error = \(error.localizedDescription)")
			Logging.logError(error)
		}
	}

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
		handleOpenURL(url: url)
		return true
	}

	private func handleOpenURL(url: URL) {
		let components = URLComponents(string: url.absoluteString)
		let indexComponent = components?.queryItems?
			.first(where: { $0.name == Constants.widgetPersonIndexKey })
		let personIndexStr = indexComponent?.value ?? ""
		var params: [String: String]?
		if let personIndex = Int(personIndexStr) {
			params = ["index": "\(personIndex)"]
			NotificationCenter.default.post(
				name: Constants.openPersonNotification, object: nil, userInfo: [Constants.widgetPersonIndexKey: personIndex])
		}
		Logging.logMessage("Open URL from Widget", params: params)
	}

}
