#if DEBUG
	import Core
	import SwiftUI
	import UIKit
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
					AgeWidgetContentView(entry: entry, family: family)
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
					var persons: [WidgetPerson] = []
					for (index, person) in people.prefix(Constants.widgetPeopleLimit).enumerated() {
						let image: UIImage?
						if let reference = PersonImage(id: person.widgetPicId) {
							image = try await configurator.loadImage(reference)
						} else {
							image = nil
						}
						persons.append(WidgetPerson(id: person.id, index: index, name: person.name, birthday: person.birthday, image: image))
					}
					entry = AgeEntry(date: configurator.now(), persons: persons)
				} catch {
					self.error = error.localizedDescription
				}
			}
		}
	}
#endif
