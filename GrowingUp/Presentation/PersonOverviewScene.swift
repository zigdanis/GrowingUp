import Core
import SwiftUI

struct PersonOverviewScene: View {
	let person: Person
	let onEdit: () -> Void
	let now: () -> Date
	@State private var presenter: OverviewPresenter

	init(person: Person, configurator: SceneConfigurator, onEdit: @escaping () -> Void) {
		self.person = person
		self.onEdit = onEdit
		now = configurator.now
		_presenter = State(initialValue: OverviewPresenter(loadImage: configurator.loadImage))
	}

	var body: some View {
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
				Button(action: onEdit) {
					Label("Edit person", systemImage: person.isOnWidget ? "person.crop.circle.badge.checkmark" : "slider.horizontal.3")
				}
				.buttonStyle(.borderedProminent)
				.accessibilityIdentifier("person.edit")
				.padding(.bottom, 48)
			}
			.padding(24)
			.foregroundStyle(.white)
		}
		.ignoresSafeArea(edges: .bottom)
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
