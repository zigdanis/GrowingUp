import Core
import Observation
import SwiftUI

/// The viewer's in-place edit mode for an existing person: what the screen shows and does while it edits, on top of the
/// `PersonEditorPresenter` session that holds the draft and saves or removes it.
///
/// The mode only ends through Cancel, which drops the draft at once without asking, or Done, which saves it. Leaving the
/// app keeps the draft as it is. `PeoplePresenter` owns the session, so a widget link or a newer session that replaces
/// it ends the mode as well.
@MainActor
@Observable
final class PersonEditModePresenter {
	let editor: PersonEditorPresenter
	/// The centred card over the screen, if any; there is only ever one.
	private(set) var popover: PersonEditPopover?
	/// Whether the removal alert is up.
	var isConfirmingRemoval = false
	/// The main photo being framed; `nil` without a photo or until it loads.
	private(set) var photo: UIImage?
	/// Where the photo sits now, rubber-banding while a pinch or drag moves it.
	private(set) var framing = PhotoFraming.identity
	/// Whether a pinch or drag is moving the photo.
	private(set) var isFraming = false
	/// Whether Done is rendering the framing and saving.
	private(set) var isFinishing = false
	/// Where the photo rests between gestures; a gesture moves it from here.
	private var restingFraming = PhotoFraming.identity
	/// The identity of the main photo `framing` belongs to; a reload of the same photo keeps it.
	private var framedPhotoID: UUID?
	/// The whole window, safe areas included: the canvas the photo fills, as on the viewer's page.
	private var canvas = CGSize.zero
	private var safeAreaInsets = EdgeInsets()
	private let now: () -> Date
	private let calendar: Calendar
	private let locale: Locale
	private let onCancel: () -> Void

	init(
		editor: PersonEditorPresenter, now: @escaping () -> Date, calendar: Calendar = .autoupdatingCurrent,
		locale: Locale = .autoupdatingCurrent, onCancel: @escaping () -> Void
	) {
		self.editor = editor
		self.now = now
		self.calendar = calendar
		self.locale = locale
		self.onCancel = onCancel
	}

	// MARK: - Fields

	/// The day of birth on its capsule, such as "Apr 19, 2026" or "19 апр. 2026 г.".
	var dateText: String {
		editor.birthday.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: calendar))
	}

	/// The time of birth on its capsule, always shown; midnight, such as "00:00", stands for an unknown time.
	var timeText: String {
		editor.birthday.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar))
	}

	/// The age the edited birthday gives right now, such as "5 years, 3 months": it confirms the date was entered right.
	var ageText: String {
		AgeSummary(birthday: editor.birthday, now: now(), finestUnit: .minutes, calendar: calendar).localizedCompact(locale: locale)
	}

	/// The removal alert's title with the person's saved name.
	var removalTitle: String {
		String(localized: "Remove \(editor.person?.name ?? editor.name)?", locale: locale)
	}

	/// The widget picture's button only makes sense with a main photo to frame it from.
	var showsWidgetPictureButton: Bool { editor.appImage != nil }

	/// Whether the photo was moved or zoomed away from how the viewer showed it.
	var hasReframed: Bool { photo != nil && framing != .identity }

	/// Done saves a changed draft with a name, a new framing counting as a change.
	var canSave: Bool {
		!isFinishing && (editor.canSave || (hasReframed && editor.isReadyToSave))
	}

	/// Cancel waits while a save is in flight, like the editor sheet's.
	var canCancel: Bool { !isFinishing && !editor.isBusy }

	// MARK: - Actions

	func show(_ popover: PersonEditPopover) {
		isConfirmingRemoval = false
		self.popover = popover
	}

	func dismissPopover() { popover = nil }

	func confirmRemoval() {
		popover = nil
		isConfirmingRemoval = true
	}

	/// Drops every edit at once; the draft is not worth a question.
	func cancel() {
		guard canCancel else { return }
		onCancel()
	}

	/// Renders a new framing into the main photo and saves the draft through the editor, which then closes the mode.
	func done() async {
		guard canSave else { return }
		isFinishing = true
		defer { isFinishing = false }
		if hasReframed, let photo, let geometry = geometry(of: photo) {
			let framed = await geometry.output(of: photo, scale: framing.scale, offset: framing.offset)
			editor.reframeMainPhoto(framed)
			// The framing now lives in the photo itself, which shows the same region at rest.
			self.photo = framed
			framedPhotoID = editor.appImage?.id
			resetFraming()
		}
		await editor.save()
	}

	func remove() async {
		isConfirmingRemoval = false
		await editor.remove()
	}

	// MARK: - Framing

	/// Loads the draft's main photo. A new or removed photo rests as the viewer would show it; the same photo loaded
	/// again, as when the screen returns from the widget picture's crop, keeps its framing.
	func loadPhoto() async {
		let photoID = editor.appImage?.id
		let loaded = await editor.loadMainPhoto()
		guard !Task.isCancelled else { return }
		photo = loaded
		if photoID != framedPhotoID || loaded == nil {
			resetFraming()
		}
		framedPhotoID = loaded == nil ? nil : photoID
	}

	/// Takes the window's size and safe area, keeping the photo covering the crop frame in a resized window.
	func updateCanvas(_ size: CGSize, safeAreaInsets: EdgeInsets) {
		canvas = size
		self.safeAreaInsets = safeAreaInsets
		guard let geometry = photo.flatMap(geometry(of:)) else { return }
		let scale = geometry.clampScale(restingFraming.scale)
		restingFraming = PhotoFraming(scale: scale, offset: geometry.clampOffset(restingFraming.offset, scale: scale))
		framing = restingFraming
	}

	/// The crop math for `photo` on the current canvas, shared with `CropStep`. The photo is drawn edge to edge while it
	/// is framed, so it keeps the whole window covered; a wider window still saves only its centred portrait column.
	func geometry(of photo: UIImage) -> CropGeometry? {
		guard canvas.width > 0, canvas.height > 0 else { return nil }
		return CropGeometry(image: photo, shape: .rectangle, container: canvas, insets: safeAreaInsets, coversWholeCanvas: true)
	}

	func drag(by translation: CGSize) {
		guard let geometry = photo.flatMap(geometry(of:)) else { return }
		isFraming = true
		let proposed = CGSize(
			width: restingFraming.offset.width + translation.width, height: restingFraming.offset.height + translation.height)
		framing.offset = geometry.rubberBandOffset(proposed, scale: framing.scale)
	}

	func endDrag() {
		guard let geometry = photo.flatMap(geometry(of:)) else { return }
		framing.offset = geometry.clampOffset(framing.offset, scale: framing.scale)
		restingFraming.offset = framing.offset
		isFraming = false
	}

	func magnify(by magnification: CGFloat) {
		guard let geometry = photo.flatMap(geometry(of:)) else { return }
		isFraming = true
		framing.scale = geometry.rubberBandedScale(restingFraming.scale * magnification)
		framing.offset = geometry.rubberBandOffset(framing.offset, scale: framing.scale)
	}

	func endMagnify() {
		guard let geometry = photo.flatMap(geometry(of:)) else { return }
		let scale = geometry.clampScale(framing.scale)
		framing = PhotoFraming(scale: scale, offset: geometry.clampOffset(framing.offset, scale: scale))
		restingFraming = framing
		isFraming = false
	}

	/// Puts the photo back as the viewer showed it.
	func resetFraming() {
		framing = .identity
		restingFraming = .identity
	}
}
