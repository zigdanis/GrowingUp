import Core
import Observation
import SwiftUI

/// The in-place edit mode of an existing person's page or of a new, still empty person: what the screen shows and does
/// while it edits, on top of the `PersonEditorPresenter` session that holds the draft and saves or removes it.
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
	/// The photo being framed: the person's original, or a main picture saved before originals were kept; `nil` without a
	/// main picture or until it loads.
	private(set) var photo: UIImage?
	/// The widget picture shown as it is while no main photo shows, as the person's page shows it: only a main photo
	/// is framed. `nil` while there is a main photo, without a widget picture, or until it loads.
	private(set) var backdrop: UIImage?
	/// Whether no picture of the draft loads, so it shows the person's monogram, as their page does. A new person's draft
	/// has none, as it gets its own monogram colour only once added.
	private(set) var showsMonogram: Bool
	/// Where the photo sits now, rubber-banding while a pinch or drag moves it.
	private(set) var framing = PhotoFraming.identity
	/// Whether a pinch or drag is moving the photo.
	private(set) var isFraming = false
	/// Whether Done is rendering the framing and saving.
	private(set) var isFinishing = false
	/// Where the photo rests between gestures; a gesture moves it from here.
	private var restingFraming = PhotoFraming.identity
	/// Where the photo shows what the saved main picture shows, as the viewer did: Done saves nothing new from here.
	private(set) var savedFraming = PhotoFraming.identity
	/// The identity of the photo `framing` belongs to; a reload of the same photo keeps it.
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
		// A person without any picture shows the monogram at once; a picture that is loading never flashes it first.
		showsMonogram = editor.person != nil && editor.appImage == nil && editor.widgetImage == nil
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

	/// Whether the draft is a new person, who is only added by Done.
	var isNewPerson: Bool { editor.person == nil }

	/// The widget picture's button only makes sense with a main photo to frame it from.
	var showsWidgetPictureButton: Bool { editor.appImage != nil }

	/// A new person has nobody to remove yet.
	var showsRemoveButton: Bool { !isNewPerson }

	/// Whether the photo was moved or zoomed away from how the viewer showed it.
	var hasReframed: Bool { photo != nil && framing != savedFraming }

	/// Done saves a changed draft with a name, a new framing counting as a change.
	var canSave: Bool {
		!isFinishing && (editor.canSave || (hasReframed && editor.isReadyToSave))
	}

	/// Cancel waits while a save is in flight.
	var canCancel: Bool { !isFinishing && !editor.isBusy }

	// MARK: - Actions

	func show(_ popover: PersonEditPopover) {
		isConfirmingRemoval = false
		self.popover = popover
		editor.analytics.track(.birthdayPickerOpened(popover))
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

	/// Renders a new framing of the photo into the main picture and saves the draft through the editor, which then closes
	/// the mode. The photo itself stays whole, so the next framing can reach back to all of it.
	func done() async {
		guard canSave else { return }
		isFinishing = true
		defer { isFinishing = false }
		if hasReframed, let photo, let geometry = geometry(of: photo) {
			let framed = await geometry.output(of: photo, scale: framing.scale, offset: framing.offset)
			editor.reframeMainPhoto(framed)
			editor.analytics.track(.photoReframed)
			// The main picture now shows this framing.
			savedFraming = framing
			restingFraming = framing
			framedPhotoID = editor.framingSource?.id
		}
		await editor.save()
	}

	func remove() async {
		isConfirmingRemoval = false
		await editor.remove()
	}

	/// Places a newly picked photo from `source`, framed in the photo flow, as the main photo.
	func placePhoto(_ framed: FramedPhoto, from source: ImageCaptureSource) {
		editor.setMainPhoto(framed)
		editor.analytics.track(.photoPicked(source: source))
	}

	/// Places a separately framed circle as the widget picture.
	func placeWidgetPicture(_ framed: FramedPhoto) {
		editor.setWidgetPhoto(framed)
		editor.analytics.track(.widgetPictureFramed)
	}

	// MARK: - Framing

	/// Loads the photo the draft's main picture is framed from, else its widget picture as the backdrop, else settles on
	/// the monogram: the person's page picks the same way. The photo opens on the region its main picture shows, as the
	/// viewer showed it; the same photo loaded again, as when the screen returns from the widget picture's crop, keeps
	/// its framing.
	func loadPhoto() async {
		let photoID = editor.framingSource?.id
		// The same photo stays loaded, and framed as it was, when only a picture framed from it changed.
		if photoID != nil, photoID == framedPhotoID, photo != nil { return }
		let loaded = await editor.loadFramingSource()
		guard !Task.isCancelled else { return }
		photo = loaded
		if photoID != framedPhotoID || loaded == nil {
			savedFraming = loaded.flatMap(geometry(of:)).map(framingOfSavedPicture(in:)) ?? .identity
			resetFraming()
		}
		framedPhotoID = loaded == nil ? nil : photoID
		guard loaded == nil else {
			backdrop = nil
			showsMonogram = false
			return
		}
		let widgetPicture = await editor.loadWidgetPicture()
		guard !Task.isCancelled else { return }
		backdrop = widgetPicture
		showsMonogram = widgetPicture == nil && !isNewPerson
	}

	/// Takes the window's size and safe area. A photo at rest where the saved picture shows it stays there on the new
	/// canvas; one moved since keeps covering the crop frame.
	func updateCanvas(_ size: CGSize, safeAreaInsets: EdgeInsets) {
		let wasReframed = restingFraming != savedFraming
		canvas = size
		self.safeAreaInsets = safeAreaInsets
		guard let geometry = photo.flatMap(geometry(of:)) else { return }
		savedFraming = framingOfSavedPicture(in: geometry)
		guard wasReframed else {
			resetFraming()
			return
		}
		let scale = geometry.clampScale(restingFraming.scale)
		restingFraming = PhotoFraming(scale: scale, offset: geometry.clampOffset(restingFraming.offset, scale: scale))
		framing = restingFraming
	}

	/// Where the photo shows the region of it the saved main picture shows.
	private func framingOfSavedPicture(in geometry: CropGeometry) -> PhotoFraming {
		// Without a stored source-relative crop, a legacy picture keeps the viewer's aspect-fill placement.
		guard editor.originalImage != nil, let crop = editor.mainCrop else {
			let scale = geometry.clampScale(1)
			return PhotoFraming(scale: scale, offset: geometry.clampOffset(.zero, scale: scale))
		}
		return geometry.framing(showing: crop)
	}

	/// The crop math shared with `CropStep`: only the crop frame must stay covered, so a saved framing that fits the
	/// portrait column in a wide window reopens without being forced to zoom in to cover the whole window.
	func geometry(of photo: UIImage) -> CropGeometry? {
		guard canvas.width > 0, canvas.height > 0 else { return nil }
		return CropGeometry(image: photo, shape: .rectangle, container: canvas, insets: safeAreaInsets)
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
		framing = savedFraming
		restingFraming = savedFraming
	}
}
