import Core
import Observation
import SwiftUI

@MainActor
@Observable
final class OverviewPresenter {
	private(set) var image: UIImage?
	private(set) var age = ""
	var error: SceneError?
	private let loadImage: (PersonImage) async throws -> UIImage

	init(loadImage: @escaping (PersonImage) async throws -> UIImage = ImagesCache.loadImageFromDiskOrMemory) {
		self.loadImage = loadImage
	}

	func load(person: Person) async {
		image = nil
		guard let picture = PersonImage(id: person.appPicId) else { return }
		do {
			let loaded = try await loadImage(picture)
			try Task.checkCancellation()
			image = loaded
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
		}
	}

	func tick(person: Person, now: Date) {
		age = AgeCalculator.ageString(for: person.dateComponents(at: now))
	}
}

struct PersonOverviewScene: View {
	let person: Person
	let onEdit: () -> Void
	@State private var presenter = OverviewPresenter()

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
				presenter.tick(person: person, now: Date())
				do { try await Task.sleep(for: .seconds(1)) } catch { break }
			}
		}
		.sceneError($presenter.error)
	}
}

struct EmptyPersonScene: View {
	let onAdd: () -> Void

	var body: some View {
		VStack(spacing: 24) {
			Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 72)).foregroundStyle(.tint)
			Button("Add person", systemImage: "plus", action: onAdd)
				.buttonStyle(.borderedProminent)
				.controlSize(.large)
				.accessibilityIdentifier("person.add")
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.systemBackground))
	}
}

extension View {
	func sceneError(_ error: Binding<SceneError?>) -> some View {
		alert(
			error.wrappedValue?.title ?? "",
			isPresented: Binding(
				get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } }
			)
		) {
			Button("OK", role: .cancel) { error.wrappedValue = nil }
		} message: {
			Text(error.wrappedValue?.message ?? "")
		}
	}
}
