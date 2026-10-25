import Core
import SwiftUI

/// The editor sheet for a new person; an existing person is edited in place in the viewer (`PersonEditModeScene`).
struct PersonEditorScene: View {
	@Bindable var presenter: PersonEditorPresenter
	@State private var photoRequest: PhotoRequest?
	@State private var reframeImage: IdentifiableImage?
	@FocusState private var isNameFocused: Bool
	@Environment(\.dismiss)
	private var dismiss

	var body: some View {
		NavigationStack {
			ScrollViewReader { proxy in
				ScrollView {
					VStack(alignment: .leading, spacing: 0) {
						PersonEditorHero(presenter: presenter, photoRequest: $photoRequest)
						VStack(alignment: .leading, spacing: 16) {
							nameField
							Divider()
							PersonBirthdayFields(presenter: presenter, proxy: proxy, onExpand: { isNameFocused = false })
							Divider()
							PersonEditorChips(presenter: presenter, onReframe: reframe)
						}
						.padding(20)
						// A centered, readable column in wide sheets, such as on an unfolded iPhone Duo.
						.frame(maxWidth: 560)
						.frame(maxWidth: .infinity)
					}
					.disabled(presenter.isBusy || presenter.isLoading)
				}
				.scrollDismissesKeyboard(.interactively)
			}
			.navigationTitle(Text("Add person"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar { toolbarItems }
			.overlay { if presenter.isBusy { ProgressView() } }
		}
		// Unsaved edits are cheap to redo, so closing the sheet drops them without asking.
		.interactiveDismissDisabled(presenter.isBusy)
		.task { await presenter.load() }
		.sceneError($presenter.error)
		.sheet(item: $photoRequest) { request in
			ImageCaptureFlowView(
				source: request.source, previewImages: presenter.photoFixtures, cropShape: .rectangle,
				onComplete: { image in
					presenter.setMainPhoto(image)
					photoRequest = nil
				}, onCancel: { photoRequest = nil }
			)
		}
		.fullScreenCover(item: $reframeImage) { item in
			CropStep(
				image: item.image, shape: .circle,
				onComplete: { cropped in
					presenter.setWidgetPhoto(cropped)
					reframeImage = nil
				}, onCancel: { reframeImage = nil }
			)
		}
	}

	private var nameField: some View {
		TextField("Name", text: $presenter.name)
			.font(.title.bold())
			.textFieldStyle(.plain)
			.textContentType(.name)
			.textInputAutocapitalization(.words)
			.submitLabel(.done)
			.focused($isNameFocused)
			.accessibilityIdentifier("editor.name")
	}

	@ToolbarContentBuilder private var toolbarItems: some ToolbarContent {
		ToolbarItem(placement: .cancellationAction) {
			Button {
				dismiss()
			} label: {
				actionLabel("Cancel", systemImage: "xmark")
			}
			.disabled(presenter.isBusy)
			.accessibilityIdentifier("editor.cancel")
		}
		ToolbarItem(placement: .confirmationAction) {
			Button {
				Task { await presenter.save() }
			} label: {
				actionLabel("Save", systemImage: "checkmark")
			}
			.disabled(!presenter.canSave)
			.accessibilityIdentifier("editor.save")
		}
	}

	/// Bars that turn vertical on iPhone Duo hide items without an icon, so iOS 27.1, which brings them, gets icons;
	/// the title stays for accessibility. Earlier systems keep the text buttons.
	@ViewBuilder
	private func actionLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
		if #available(iOS 27.1, *) {
			Label(title, systemImage: systemImage)
		} else {
			Text(title)
		}
	}

	private func reframe() {
		Task {
			guard let image = await presenter.loadMainPhoto() else { return }
			reframeImage = IdentifiableImage(image: image)
		}
	}
}
