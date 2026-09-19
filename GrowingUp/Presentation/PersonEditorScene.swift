import Core
import SwiftUI

private struct PhotoRequest: Identifiable {
	let id = UUID()
	let isWidget: Bool
	let source: ImageCaptureSource
}

struct PersonEditorScene: View {
	@Bindable var presenter: PersonEditorPresenter
	@State private var photoRequest: PhotoRequest?
	@State private var confirmingRemoval = false

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("Name", text: $presenter.name).accessibilityIdentifier("editor.name")
					DatePicker("Birthday", selection: $presenter.birthday, in: ...Date())
						.accessibilityIdentifier("editor.birthday")
					Toggle("Add to Widget", isOn: $presenter.isOnWidget)
						.accessibilityIdentifier("editor.pin")
				}
				Section {
					HStack(spacing: 32) {
						pictureMenu(isWidget: false)
						pictureMenu(isWidget: true)
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical)
				}
				if presenter.person != nil {
					Section {
						Button("Remove", role: .destructive) { confirmingRemoval = true }
							.accessibilityIdentifier("editor.remove")
					}
				}
			}
			.disabled(presenter.isBusy || presenter.isLoading)
			.navigationTitle(presenter.name.isEmpty ? String(localized: "Add person") : presenter.name)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", action: presenter.cancel).disabled(presenter.isBusy)
						.accessibilityIdentifier("editor.cancel")
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") { Task { await presenter.save() } }
						.disabled(presenter.isBusy || presenter.isLoading)
						.accessibilityIdentifier("editor.save")
				}
			}
			.overlay { if presenter.isBusy { ProgressView() } }
			.confirmationDialog("Remove person?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
				Button("Remove", role: .destructive) { Task { await presenter.remove() } }
			}
		}
		.interactiveDismissDisabled(presenter.isBusy)
		.task { await presenter.load() }
		.sceneError($presenter.error)
		.sheet(item: $photoRequest) { request in
			ImageCaptureFlowView(
				source: request.source, cropShape: request.isWidget ? .circle : .rectangle,
				onComplete: { image in
					let picture = PersonImage(uiImage: image)
					if request.isWidget { presenter.widgetImage = picture } else { presenter.appImage = picture }
					photoRequest = nil
				}, onCancel: { photoRequest = nil }
			)
			.presentationDetents([.large])
		}
	}

	private func pictureMenu(isWidget: Bool) -> some View {
		Menu {
			Button("Photos", systemImage: "photo") {
				photoRequest = PhotoRequest(isWidget: isWidget, source: .photos)
			}
			Button("Camera", systemImage: "camera") {
				photoRequest = PhotoRequest(isWidget: isWidget, source: .camera)
			}
			Button("Remove", systemImage: "trash", role: .destructive) {
				if isWidget { presenter.widgetImage = nil } else { presenter.appImage = nil }
			}
		} label: {
			VStack {
				PersonPicture(image: isWidget ? presenter.widgetImage : presenter.appImage)
				Text(isWidget ? LocalizedStringKey("widget pic") : LocalizedStringKey("main pic"))
			}
		}
		.accessibilityLabel(isWidget ? Text("Change widget picture") : Text("Change app picture"))
		.accessibilityIdentifier(isWidget ? "editor.widgetPhoto" : "editor.appPhoto")
	}
}

private struct PersonPicture: View {
	let image: PersonImage?
	@State private var loaded: UIImage?

	var body: some View {
		ZStack {
			Circle().fill(.quaternary)
			if let loaded {
				Image(uiImage: loaded).resizable().scaledToFill()
			} else {
				Image(systemName: "photo.badge.plus").font(.largeTitle)
			}
		}
		.frame(width: 96, height: 96)
		.clipShape(.circle)
		.task(id: image?.id) {
			loaded = image?.uiImage
			guard let image, loaded == nil else { return }
			loaded = try? await ImagesCache.loadImageFromDiskOrMemory(image: image)
		}
	}
}
