//
//  GrowingUpApp.swift
//  GrowingUp
//
//  Copyright © 2026 Danis Ziganshin.
//

import SwiftUI

@main
struct GrowingUpApp: App {
	@State private var presenter: PeoplePresenter
	private let preferredColorScheme: ColorScheme?

	init() {
		let launchMode = AppLaunchMode.current
		preferredColorScheme = launchMode.preferredColorScheme
		_presenter = State(initialValue: PeoplePresenter(configurator: AppComposition.make(for: launchMode)))
	}

	var body: some Scene {
		WindowGroup {
			PeopleScene(presenter: presenter)
				.tint(Color(uiColor: .appColor))
				.preferredColorScheme(preferredColorScheme)
		}
	}
}
