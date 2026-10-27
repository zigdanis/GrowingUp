import Core
import SwiftUI

/// The viewer's page of an existing person, turned editable in place: the photo frames under a thirds grid, the name
/// becomes a field, the birthday turns into date and time capsules, and round controls line the bottom. A new person
/// gets the same screen, empty, with the keyboard up on the name.
///
/// Only Cancel and Done leave it; `PersonViewer` locks its swipes meanwhile.
struct PersonEditModeScene: View {
	@Bindable var mode: PersonEditModePresenter
	let layout: PersonPageLayout
	/// The whole window, safe areas included, since the photo draws edge to edge like the viewer's page.
	let window: CGSize
	let safeAreaInsets: EdgeInsets
	@State private var photoRequest: PhotoRequest?
	@State private var widgetPictureSource: IdentifiableImage?
	@FocusState private var isNameFocused: Bool

	var body: some View {
		@Bindable var editor = mode.editor
		ZStack {
			EditModePhoto(mode: mode, window: window)
			scrim
			controls
				.frame(maxWidth: columnWidth)
				.frame(maxWidth: .infinity)
				.disabled(editor.isBusy || editor.isLoading || mode.isFinishing)
				// VoiceOver's escape gesture cancels, like the Cancel in the corner.
				.accessibilityElement(children: .contain)
				.accessibilityAction(.escape) { mode.cancel() }
			if let popover = mode.popover {
				EditModePopoverCard(
					mode: mode, popover: popover, maxWidth: min(window.width - safeAreaInsets.leading - safeAreaInsets.trailing, 440),
					safeAreaInsets: safeAreaInsets
				)
				.transition(.opacity)
			}
			if editor.isBusy || mode.isFinishing { ProgressView() }
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.ignoresSafeArea(.container)
		.animation(.easeOut(duration: 0.2), value: mode.popover)
		.task { await editor.load() }
		// A new person is named first, as soon as the loaded fields take input; the photo can follow.
		.onChange(of: editor.isLoading) { _, isLoading in
			if !isLoading, mode.isNewPerson { isNameFocused = true }
		}
		// Removing a widget picture shown alone changes no main photo, yet it leaves the monogram in its place.
		.task(id: [editor.appImage?.id, editor.widgetImage?.id]) { await mode.loadPhoto() }
		.onChange(of: window, initial: true) { _, size in mode.updateCanvas(size, safeAreaInsets: safeAreaInsets) }
		.alert(mode.removalTitle, isPresented: $mode.isConfirmingRemoval) {
			Button("Remove", role: .destructive) { Task { await mode.remove() } }
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Their photo, birthday and settings will disappear from the app and the widget.")
		}
		.sceneError($editor.error)
		.sheet(item: $photoRequest) { request in
			// A new photo lands in the frame, where it can be framed again before Done.
			ImageCaptureFlowView(
				source: request.source, previewImages: editor.photoFixtures, cropShape: .rectangle,
				onComplete: { framed in
					editor.setMainPhoto(framed)
					photoRequest = nil
				}, onCancel: { photoRequest = nil }
			)
		}
		// The circle opens on the region its picture shows, framed from the same photo as the main picture.
		.fullScreenCover(item: $widgetPictureSource) { item in
			CropStep(
				image: item.image, shape: .circle, initialCrop: editor.widgetImage?.crop,
				onComplete: { framed in
					editor.setWidgetPhoto(framed)
					widgetPictureSource = nil
				}, onCancel: { widgetPictureSource = nil }
			)
		}
	}

	/// The fields at the top and the controls at the bottom, clear of the safe areas, with the middle left to the photo.
	/// When the largest text sizes leave them no room, as on a small iPhone, they scroll rather than clip.
	private var controls: some View {
		ViewThatFits(in: .vertical) {
			stack
			ScrollView { stack }
				.scrollBounceBehavior(.basedOnSize)
		}
	}

	private var stack: some View {
		VStack(spacing: 0) {
			topBar
				.padding(.bottom, 16)
			EditModeFields(mode: mode, isNameFocused: $isNameFocused)
			Spacer(minLength: 24)
			EditModeControls(mode: mode, photoRequest: $photoRequest, onFrameWidgetPicture: frameWidgetPicture)
				.padding(.bottom, 16)
		}
		.padding(.horizontal, 20)
		.padding(.top, safeAreaInsets.top + 8)
		.padding(.bottom, safeAreaInsets.bottom)
		.padding(.leading, safeAreaInsets.leading)
		.padding(.trailing, safeAreaInsets.trailing)
	}

	/// Cancel and Done share one compact capsule, so they line up at any text size and in any language. They keep to one
	/// line, growing up to a size that leaves room for both; beyond it, a long press shows them in the large content
	/// viewer, as a navigation bar does.
	private var topBar: some View {
		HStack {
			Button("Cancel") {
				mode.cancel()
			}
			.buttonStyle(EditModeBarButtonStyle(isProminent: false))
			.disabled(!mode.canCancel)
			.accessibilityShowsLargeContentViewer()
			.accessibilityIdentifier("editor.cancel")
			Spacer()
			Button("Done") {
				isNameFocused = false
				Task { await mode.done() }
			}
			.buttonStyle(EditModeBarButtonStyle(isProminent: true))
			.disabled(!mode.canSave)
			.accessibilityShowsLargeContentViewer()
			.accessibilityIdentifier("editor.save")
		}
		.lineLimit(1)
		.dynamicTypeSize(...DynamicTypeSize.accessibility1)
	}

	/// The crop frame's width: the window on a phone, a centred portrait column in wider windows.
	private var columnWidth: CGFloat? {
		guard layout != .phone else { return nil }
		let column = CropGeometry.frameRect(for: .rectangle, in: window, insets: safeAreaInsets).width
		return min(column, layout.columnWidth ?? column)
	}

	/// Darkens the top behind the fields and the bottom behind the controls, so white text stays readable on light photos.
	private var scrim: some View {
		LinearGradient(
			stops: [
				.init(color: .black.opacity(0.55), location: 0),
				.init(color: .black.opacity(0.15), location: 0.35),
				.init(color: .clear, location: 0.55),
				.init(color: .black.opacity(0.55), location: 1)
			],
			startPoint: .top, endPoint: .bottom
		)
		.allowsHitTesting(false)
		.accessibilityHidden(true)
	}

	private func frameWidgetPicture() {
		guard let photo = mode.photo else { return }
		widgetPictureSource = IdentifiableImage(image: photo)
	}
}
