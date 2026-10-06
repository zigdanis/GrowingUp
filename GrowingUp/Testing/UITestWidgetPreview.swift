#if DEBUG
	import Core
	import SwiftUI
	import WidgetKit

	/// Exercises the extension's actual rendering against the isolated UI-test store.
	/// WidgetKit Home Screen hosting still needs a device check.
	struct UITestWidgetPreview: View {
		let configurator: SceneConfigurator
		let familyName: String
		@State private var entry: AgeEntry?
		@State private var error: String?

		private var family: WidgetFamily {
			switch familyName {
			case "small": .systemSmall
			case "medium": .systemMedium
			default: .systemLarge
			}
		}

		var body: some View {
			ZStack {
				Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
				if let entry {
					AgeWidgetEntryView(entry: entry)
						.environment(\.widgetFamily, family)
						.padding(16)
						.frame(width: family == .systemSmall ? 170 : 364, height: family == .systemLarge ? 382 : 170)
						.background(.background, in: RoundedRectangle(cornerRadius: 24))
						.accessibilityIdentifier("widget.preview")
				} else if let error {
					Text(error).accessibilityIdentifier("widget.preview.error")
				} else {
					ProgressView()
				}
			}
			.task {
				do {
					let people = try await configurator.fetchUseCase.fetchWidgetPersons()
					let persons = people.prefix(Constants.widgetPeopleLimit).enumerated().map { index, person in
						WidgetPerson(id: person.id, index: index, name: person.name, birthday: person.birthday, image: nil)
					}
					entry = AgeEntry(date: configurator.now(), persons: persons)
				} catch {
					self.error = error.localizedDescription
				}
			}
		}
	}
#endif
