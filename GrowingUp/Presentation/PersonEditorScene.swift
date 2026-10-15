import Core
import SwiftUI

struct PersonEditorScene: View {
	@Bindable var presenter: PersonEditorPresenter
	@State private var photoRequest: PhotoRequest?
	@State private var reframeImage: IdentifiableImage?
	@State private var confirmingDiscard = false
	@State private var confirmingRemoval = false
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
					}
					.disabled(presenter.isBusy || presenter.isLoading)
				}
				.scrollDismissesKeyboard(.interactively)
			}
			.navigationTitle(presenter.person == nil ? Text("Add person") : Text("Edit person"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar { toolbarItems }
			.overlay { if presenter.isBusy { ProgressView() } }
		}
		.interactiveDismissDisabled(presenter.isBusy || presenter.isDirty)
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
					presenter.setWidgetPhoto(cropped.downsized(maxPixelSide: CropShape.circle.maxPixelSize))
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
			Button("Cancel", action: cancel)
				.disabled(presenter.isBusy)
				.accessibilityIdentifier("editor.cancel")
				.confirmationDialog("Discard changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
					Button("Discard", role: .destructive) { dismiss() }
						.accessibilityIdentifier("editor.discard")
					Button("Keep editing", role: .cancel) {}
				}
		}
		if presenter.person != nil {
			ToolbarItem(placement: .topBarTrailing) {
				Menu {
					Button("Remove…", systemImage: "trash", role: .destructive) { confirmingRemoval = true }
						.accessibilityIdentifier("editor.remove")
				} label: {
					Label("More", systemImage: moreSymbol)
				}
				.disabled(presenter.isBusy)
				.accessibilityIdentifier("editor.menu")
				// Attached to the menu button so iOS 26 anchors the confirmation to it.
				.confirmationDialog("Remove person?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
					Button("Remove", role: .destructive) { Task { await presenter.remove() } }
				}
			}
		}
		ToolbarItem(placement: .confirmationAction) {
			Button("Save") { Task { await presenter.save() } }
				.disabled(!presenter.canSave)
				.accessibilityIdentifier("editor.save")
		}
	}

	/// Liquid Glass already draws a circle around toolbar items, so only older systems need the circled symbol.
	private var moreSymbol: String {
		if #available(iOS 26.0, *) { return "ellipsis" }
		return "ellipsis.circle"
	}

	private func cancel() {
		if presenter.isDirty {
			confirmingDiscard = true
		} else {
			dismiss()
		}
	}

	private func reframe() {
		Task {
			guard let image = await presenter.loadMainPhoto() else { return }
			reframeImage = IdentifiableImage(image: image)
		}
	}
}
