import Core
import SwiftUI

struct PersonEditorScene: View {
	@Bindable var presenter: PersonEditorPresenter
	@State private var photoRequest: PhotoRequest?
	@State private var confirmingRemoval = false
	@FocusState private var isNameFocused: Bool

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("Name", text: $presenter.name)
						.textContentType(.givenName)
						.focused($isNameFocused)
						.multilineTextAlignment(.center)
						.accessibilityIdentifier("editor.name")
				}
				Section {
					PersonBirthdayFields(presenter: presenter, onExpand: { isNameFocused = false })
					Toggle("Add to Widget", isOn: $presenter.isOnWidget)
						.accessibilityIdentifier("editor.pin")
				}
				Section {
					HStack(spacing: 24) {
						PersonPhotoMenu(presenter: presenter, isWidget: false, photoRequest: $photoRequest)
						PersonPhotoMenu(presenter: presenter, isWidget: true, photoRequest: $photoRequest)
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 16)
					.padding(.horizontal, 8)
				}
				if presenter.person != nil {
					Section {
						Button(role: .destructive) {
							confirmingRemoval = true
						} label: {
							Text("Remove").frame(maxWidth: .infinity)
						}
						.accessibilityIdentifier("editor.remove")
						.confirmationDialog("Remove person?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
							Button("Remove", role: .destructive) { Task { await presenter.remove() } }
						}
					}
				}
			}
			.disabled(presenter.isBusy || presenter.isLoading)
			.navigationTitle(presenter.name.isEmpty ? String(localized: "Add person") : presenter.name)
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Save", systemImage: "checkmark") { Task { await presenter.save() } }
						.labelStyle(.iconOnly)
						.disabled(presenter.isBusy || presenter.isLoading)
						.accessibilityIdentifier("editor.save")
				}
			}
			.overlay { if presenter.isBusy { ProgressView() } }
		}
		.interactiveDismissDisabled(presenter.isBusy)
		.task { await presenter.load() }
		.sceneError($presenter.error)
		.sheet(item: $photoRequest) { request in
			ImageCaptureFlowView(
				source: request.source, previewImages: presenter.photoFixtures, cropShape: request.isWidget ? .circle : .rectangle,
				onComplete: { image in
					let picture = PersonImage(uiImage: image)
					if request.isWidget { presenter.widgetImage = picture } else { presenter.appImage = picture }
					photoRequest = nil
				}, onCancel: { photoRequest = nil }
			)
		}
	}

}
