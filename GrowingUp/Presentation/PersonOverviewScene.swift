import Core
import SwiftUI

struct PersonOverviewScene: View {
	let person: Person
	let onEdit: () -> Void
	let safeAreaInsets: EdgeInsets
	let now: () -> Date
	@State private var presenter: OverviewPresenter

	init(person: Person, configurator: SceneConfigurator, safeAreaInsets: EdgeInsets, onEdit: @escaping () -> Void) {
		self.person = person
		self.onEdit = onEdit
		self.safeAreaInsets = safeAreaInsets
		now = configurator.now
		_presenter = State(initialValue: OverviewPresenter(loadImage: configurator.loadImage))
	}

	var body: some View {
		Button(action: onEdit) {
			ZStack {
				Color.black
				if let image = presenter.image {
					GeometryReader { geometry in
						Image(uiImage: image)
							.resizable()
							.scaledToFill()
							.frame(width: geometry.size.width, height: geometry.size.height)
							.clipped()
					}
				} else {
					LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
					Text("🤷").font(.system(size: 100))
				}
				LinearGradient(
					colors: [.black.opacity(0.45), .clear, .black.opacity(0.65)],
					startPoint: .top, endPoint: .bottom)
				VStack(spacing: 20) {
					Text(person.name).font(.largeTitle.bold()).accessibilityIdentifier("person.name")
					Text(presenter.age).font(.title2).multilineTextAlignment(.center)
						.accessibilityIdentifier("person.age")
					Spacer()
				}
				.padding(24)
				.padding(.top, safeAreaInsets.top)
				.padding(.bottom, safeAreaInsets.bottom)
				.foregroundStyle(.white)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityElement(children: .contain)
		.accessibilityLabel(Text("Edit person"))
		.accessibilityIdentifier("person.edit")
		.task(id: person.appPicId) { await presenter.load(person: person) }
		.task(id: person.birthday) {
			while !Task.isCancelled {
				presenter.tick(person: person, now: now())
				do { try await Task.sleep(for: .seconds(1)) } catch { break }
			}
		}
		.sceneError($presenter.error)
	}
}
