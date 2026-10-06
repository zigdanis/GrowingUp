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
			#if DEBUG
				if case .uiTest = AppLaunchMode.current,
					let family = ProcessInfo.processInfo.environment["GROWINGUP_WIDGET_PREVIEW"]
				{
					UITestWidgetPreview(configurator: presenter.configurator, familyName: family)
						.preferredColorScheme(preferredColorScheme)
				} else {
					PeopleScene(presenter: presenter, preferredColorScheme: preferredColorScheme)
						.tint(Color(uiColor: .appColor))
				}
			#else
				PeopleScene(presenter: presenter, preferredColorScheme: preferredColorScheme)
					.tint(Color(uiColor: .appColor))
			#endif
		}
	}
}
