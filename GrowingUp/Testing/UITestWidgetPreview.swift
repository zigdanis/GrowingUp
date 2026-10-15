#if DEBUG
	import Core
	import SwiftUI
	import UIKit
	import WidgetKit

	/// Exercises the extension's actual rendering against the isolated UI-test store.
	/// WidgetKit Home Screen and Lock Screen hosting still needs a device check. The app cannot set
	/// `widgetRenderingMode`, so the Lock Screen families render in their full-color StandBy look.
	struct UITestWidgetPreview: View {
		let configurator: SceneConfigurator
		let familyName: String
		@State private var entry: AgeEntry?

		private var family: WidgetFamily {
			switch familyName {
			case "small": .systemSmall
			case "medium": .systemMedium
			case "circular": .accessoryCircular
			case "rectangular": .accessoryRectangular
			case "inline": .accessoryInline
			default: .systemLarge
			}
		}

		private var isLockScreen: Bool {
			[.accessoryCircular, .accessoryRectangular, .accessoryInline].contains(family)
		}

		/// Lock Screen widget sizes of a 6.3-inch iPhone.
		private var lockScreenSize: CGSize {
			switch family {
			case .accessoryCircular: CGSize(width: 76, height: 76)
			case .accessoryInline: CGSize(width: 257, height: 26)
			default: CGSize(width: 172, height: 76)
			}
		}

		var body: some View {
			ZStack {
				if isLockScreen {
					LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
				} else {
					Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
				}
				if let entry {
					widget(entry)
						.accessibilityElement(children: .contain)
						.accessibilityIdentifier("widget.preview")
				} else {
					ProgressView()
				}
			}
			.task {
				let useCase = configurator.fetchUseCase
				let loader = WidgetPersonLoader(fetch: { try await useCase.fetchWidgetPersons() }, loadImage: configurator.loadImage)
				let persons = await loader.load(limit: isLockScreen ? 1 : Constants.widgetPeopleLimit)
				entry = AgeEntry(date: configurator.now(), persons: persons)
			}
		}

		@ViewBuilder
		private func widget(_ entry: AgeEntry) -> some View {
			if isLockScreen {
				// White content, as on a dark Lock Screen.
				LockScreenWidgetContentView(entry: LockScreenEntry(date: entry.date, person: entry.persons.first), family: family)
					.frame(width: lockScreenSize.width, height: lockScreenSize.height)
					.environment(\.colorScheme, .dark)
			} else {
				// Outside WidgetKit there is no container background, so the widget background is drawn directly.
				AgeWidgetContentView(entry: entry, family: family)
					.padding(16)
					.frame(width: family == .systemSmall ? 170 : 364, height: family == .systemLarge ? 382 : 170)
					.background { AgeWidgetBackground(entry: entry, family: family) }
					.background(.background)
					.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
			}
		}
	}
#endif
