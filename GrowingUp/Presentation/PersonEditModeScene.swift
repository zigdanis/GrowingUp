import Core
import SwiftUI

/// The viewer's page of an existing person, turned editable in place: the photo frames under a thirds grid, the name
/// becomes a field, the birthday turns into date and time capsules, and round controls line the bottom.
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
		.task(id: editor.appImage?.id) { await mode.loadPhoto() }
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
				onComplete: { image in
					editor.setMainPhoto(image)
					photoRequest = nil
				}, onCancel: { photoRequest = nil }
			)
		}
		.fullScreenCover(item: $widgetPictureSource) { item in
			CropStep(
				image: item.image, shape: .circle,
				onComplete: { cropped in
					editor.setWidgetPhoto(cropped)
					widgetPictureSource = nil
				}, onCancel: { widgetPictureSource = nil }
			)
		}
	}

	/// The fields at the top and the controls at the bottom, clear of the safe areas, with the middle left to the photo.
	private var controls: some View {
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

	private var topBar: some View {
		HStack {
			Button {
				mode.cancel()
			} label: {
				Text("Cancel")
					.font(.headline)
					.foregroundStyle(.white)
					.padding(.horizontal, 6)
					.frame(minHeight: 32)
			}
			.modifier(GlassCapsuleButtonChrome(prominent: false))
			.controlSize(.large)
			.disabled(!mode.canCancel)
			.accessibilityIdentifier("editor.cancel")
			Spacer()
			Button {
				isNameFocused = false
				Task { await mode.done() }
			} label: {
				Text("Done")
					.font(.headline)
					.foregroundStyle(.black)
					.padding(.horizontal, 18)
					.frame(minHeight: 44)
					.background(.white, in: Capsule())
					.contentShape(Capsule())
			}
			.buttonStyle(.plain)
			.opacity(mode.canSave ? 1 : 0.45)
			.disabled(!mode.canSave)
			.accessibilityIdentifier("editor.save")
		}
	}

	/// The crop frame's width: the window on a phone, a centred portrait column in wider windows.
	private var columnWidth: CGFloat? {
		guard layout != .phone else { return nil }
		let column = CropGeometry(pixelSize: window, shape: .rectangle, container: window, insets: safeAreaInsets).frameRect.width
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
