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
				#if DEBUG
					.overlay(alignment: .topLeading) { UITestAppearanceProbe() }
					.preferredColorScheme(UITestComposition.colorScheme)
				#endif
		}
	}
}
