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
	@Environment(\.haptics)
	private var haptics

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
				.accessibilityAction(.escape, cancel)
			// A tall enough iPad window pops the pickers over their capsules instead.
			if let popover = mode.popover, !popsOverCapsules {
				EditModePopoverCard(
					mode: mode, popover: popover, maxWidth: min(window.width - safeAreaInsets.leading - safeAreaInsets.trailing, 440),
					safeAreaInsets: safeAreaInsets
				)
				.transition(.opacity)
			}
			if editor.isBusy || mode.isFinishing { ProgressView() }
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background {
			// While the name field has no keyboard, Escape closes a picker or else cancels, and Command-Return saves; the
			// field answers Command-Return itself while it has the keyboard. A sheet, cover or confirmation shown over
			// edit mode keeps its own keys, so the anchor leaves until it closes.
			if !isNameFocused, photoRequest == nil, widgetPictureSource == nil, !mode.isConfirmingRemoval {
				KeyboardFocusAnchor(commands: keyboardCommands).frame(width: 0, height: 0)
			}
		}
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
		.modifier(RemovalConfirmation(mode: mode, isOnButton: false))
		.onChange(of: mode.isConfirmingRemoval) { _, isConfirming in
			if isConfirming { haptics.play(.removalConfirmationShown) }
		}
		.sceneError($editor.error)
		.sheet(item: $photoRequest) { request in
			// A new photo lands in the frame, where it can be framed again before Done.
			ImageCaptureFlowView(
				source: request.source, previewImages: editor.photoFixtures, cropShape: .rectangle,
				onComplete: { framed in
					mode.placePhoto(framed, from: request.source)
					photoRequest = nil
				}, onCancel: { photoRequest = nil }
			)
		}
		// The circle opens on the region its picture shows, framed from the same photo as the main picture.
		.fullScreenCover(item: $widgetPictureSource) { item in
			CropStep(
				image: item.image, shape: .circle, initialCrop: editor.widgetImage?.crop,
				onComplete: { framed in
					mode.placeWidgetPicture(framed)
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
				.modifier(WindowControlsClearance(edges: .leading))
				.padding(.bottom, 16)
			EditModeFields(mode: mode, isNameFocused: $isNameFocused, popsOver: popsOverCapsules, onSave: saveFromKeyboard)
			Spacer(minLength: 24)
			EditModeControls(mode: mode, photoRequest: $photoRequest, onFrameWidgetPicture: frameWidgetPicture)
				.padding(.bottom, 16)
		}
		.padding(.horizontal, Self.chromeMargin)
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
				cancel()
			}
			.buttonStyle(EditModeBarButtonStyle(isProminent: false))
			.disabled(!mode.canCancel)
			.accessibilityShowsLargeContentViewer()
			.accessibilityIdentifier("editor.cancel")
			Spacer()
			Button("Done", action: done)
				.buttonStyle(EditModeBarButtonStyle(isProminent: true))
				.disabled(!mode.canSave)
				.accessibilityShowsLargeContentViewer()
				.accessibilityIdentifier("editor.save")
		}
		.lineLimit(1)
		.dynamicTypeSize(...DynamicTypeSize.accessibility1)
	}

	/// Whether the pickers pop over their capsules: on iPad, in a window wider than a phone's and tall enough to hold the
	/// calendar beside them. A phone-sized window shows the card, as a phone does.
	private var popsOverCapsules: Bool {
		UIDevice.current.userInterfaceIdiom == .pad && layout != .phone
			&& window.height >= EditModePopoverCard.minimumPopoverWindowHeight
	}

	private func done() {
		isNameFocused = false
		// Read now: the scene is gone once the save lands.
		let feedback = haptics
		Task {
			if await mode.done() { feedback.play(.saved) }
		}
	}

	/// Saves from a keyboard shortcut whenever Done would take a tap: enabled, with no load or save under way.
	private func saveFromKeyboard() {
		guard mode.canSave, !mode.editor.isBusy, !mode.editor.isLoading, !mode.isFinishing else { return }
		done()
	}

	private var keyboardCommands: [KeyboardCommand] {
		KeyboardCommand.editMode(
			escape: {
				if mode.popover != nil {
					mode.dismissPopover()
				} else {
					cancel()
				}
			}, save: saveFromKeyboard)
	}

	private var columnWidth: CGFloat? {
		Self.columnWidth(layout: layout, window: window, insets: safeAreaInsets, idiom: UIDevice.current.userInterfaceIdiom)
	}

	/// The margin at the sides of the fields and controls.
	static let chromeMargin: CGFloat = 20

	/// The narrowest the fields and controls get on iPad, even beside a narrower crop column, so at the default text size
	/// the controls keep to one row and the date and time share one.
	static let padMinimumChromeWidth: CGFloat = 420

	/// The width of the fields' and controls' column, its margins and the safe areas included: the window on a
	/// phone-sized window, else the crop frame's centred portrait column up to the layout's column. On iPad the column
	/// keeps `padMinimumChromeWidth` for the controls, or the whole window when narrower, while the photo keeps the crop
	/// frame.
	static func columnWidth(layout: PersonPageLayout, window: CGSize, insets: EdgeInsets, idiom: UIUserInterfaceIdiom) -> CGFloat? {
		guard layout != .phone else { return nil }
		let crop = CropGeometry.frameRect(for: .rectangle, in: window, insets: insets, idiom: idiom).width
		let column = min(crop, layout.columnWidth ?? crop)
		guard idiom == .pad else { return column }
		let margins = 2 * chromeMargin + insets.leading + insets.trailing
		return max(column, min(window.width, padMinimumChromeWidth + margins))
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

	private func cancel() {
		guard mode.canCancel else { return }
		haptics.play(.cancelled)
		mode.cancel()
	}

	private func frameWidgetPicture() {
		guard let photo = mode.photo else { return }
		widgetPictureSource = IdentifiableImage(image: photo)
	}
}
