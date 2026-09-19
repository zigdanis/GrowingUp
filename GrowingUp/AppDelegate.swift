//
//  AppDelegate.swift
//  GrowingUp
//
//  Created by zigdanis on 14/12/2018.
//  Copyright © 2018-2026 Danis Ziganshin.
//

import Core
import SwiftUI
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {

	func application(
		_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
	) -> Bool {
		setupFileProtectionLevelForSharedContainer()
		Logging.setup()
		return true
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

}

@main
struct GrowingUpApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self)
	private var appDelegate
	@State private var presenter: PeoplePresenter

	init() {
		let configurator: SceneConfigurator
		#if DEBUG
			do { configurator = try UITestComposition.make() ?? .live() } catch { fatalError("UI test store failed: \(error)") }
		#else
			configurator = .live()
		#endif
		_presenter = State(initialValue: PeoplePresenter(configurator: configurator))
	}

	var body: some Scene {
		WindowGroup {
			PeopleScene(presenter: presenter).tint(Color(uiColor: .appColor))
		}
	}
}
