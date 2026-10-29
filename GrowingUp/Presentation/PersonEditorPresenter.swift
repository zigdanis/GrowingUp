import Core
import Observation
import UIKit

@MainActor
@Observable
final class PersonEditorPresenter {
	let person: Person?
	let maximumBirthday: Date
	let loadImage: (PersonImage) async throws -> UIImage
	/// Decodes a stored original at its full size; see `ImagesCache.loadOriginal(image:)`.
	let loadOriginal: (PersonImage) async throws -> UIImage
	let photoFixtures: [UIImage]?
	let analytics: AnalyticsGateway
	var name: String
	private(set) var birthday: Date
	var isOnWidget: Bool
	var celebratesBirthdays: Bool
	/// The main picture, with the region of `framingSource` it shows.
	var appImage: PersonImage?
	/// The widget picture, with the region of `framingSource` it shows when that is known.
	var widgetImage: PersonImage?
	/// The photo as it was picked; nil for a photo picked before originals were kept, until it is first framed again.
	var originalImage: PersonImage?
	var error: SceneError?
	private(set) var isBusy = false
	private(set) var isLoading = true
	/// Whether the widget picture is the one `setMainPhoto(_:)` derived in this session, so a reframed main photo can take
	/// it along. A widget picture framed separately, or one saved earlier, is never re-derived.
	private(set) var widgetPictureIsDerived = false
	private var birthTimeIsKnown: Bool
	/// The persisted fields as they were when `load()` finished; `isDirty` compares against it.
	private var baseline: AddPersonParameters?
	private let addUseCase: AddPersonUseCase
	private let editUseCase: EditPersonUseCase
	private let removeUseCase: RemovePersonUseCase
	private let fetchUseCase: FetchPersonsUseCase
	private let onMutation: (PersonMutation) -> Void

	init(
		person: Person?, addUseCase: AddPersonUseCase, editUseCase: EditPersonUseCase,
		removeUseCase: RemovePersonUseCase, fetchUseCase: FetchPersonsUseCase,
		now: Date = Date(), loadImage: @escaping (PersonImage) async throws -> UIImage = ImagesCache.loadImageFromDiskOrMemory,
		loadOriginal: @escaping (PersonImage) async throws -> UIImage = ImagesCache.loadOriginal,
		photoFixtures: [UIImage]? = nil, analytics: AnalyticsGateway = NoopAnalyticsGateway(),
		onMutation: @escaping (PersonMutation) -> Void
	) {
		let calendar = Calendar.current
		let birthday = person?.birthday ?? calendar.startOfDay(for: now)
		self.person = person
		maximumBirthday = now
		self.loadImage = loadImage
		self.loadOriginal = loadOriginal
		self.photoFixtures = photoFixtures
		self.analytics = analytics
		name = person?.name ?? ""
		self.birthday = birthday
		birthTimeIsKnown = birthday != calendar.startOfDay(for: birthday)
		isOnWidget = person?.isOnWidget ?? false
		celebratesBirthdays = person?.celebratesBirthdays ?? true
		appImage = PersonImage(id: person?.appPicId, crop: person?.appPicCrop)
		widgetImage = PersonImage(id: person?.widgetPicId, crop: person?.widgetPicCrop)
		originalImage = PersonImage(id: person?.originalPicId)
		self.addUseCase = addUseCase
		self.editUseCase = editUseCase
		self.removeUseCase = removeUseCase
		self.fetchUseCase = fetchUseCase
		self.onMutation = onMutation
	}

	/// Whether the time of birth is known.
	///
	/// `CoreDataPerson.birthdate` is a single date without a "has time" flag, so an unknown time is stored as
	/// local midnight (00:00:00), which the time capsule shows. The time counts as known only when the stored time
	/// of day is not exactly midnight, or once a time is picked; a picked time stores its hour and minute with zero
	/// seconds. A birth time explicitly picked as 00:00 therefore reopens as unknown.
	var hasBirthTime: Bool { birthTimeIsKnown }

	/// The calendar day of birth; setting it keeps the time of birth.
	var dayOfBirth: Date {
		get { birthday }
		set {
			let calendar = Calendar.current
			guard birthTimeIsKnown else {
				birthday = clamped(calendar.startOfDay(for: newValue))
				return
			}
			let time = calendar.dateComponents([.hour, .minute, .second], from: birthday)
			updateBirthday(day: newValue, hour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0)
		}
	}

	/// The time of birth; setting it keeps the day and marks the time as known.
	var timeOfBirth: Date {
		get { birthday }
		set {
			birthTimeIsKnown = true
			let time = Calendar.current.dateComponents([.hour, .minute], from: newValue)
			updateBirthday(day: birthday, hour: time.hour ?? 0, minute: time.minute ?? 0, second: 0)
		}
	}

	/// Whether any persisted field differs from its state when loading finished.
	var isDirty: Bool {
		guard let baseline else { return false }
		return parameters != baseline
	}

	var canSave: Bool { isDirty && isReadyToSave }

	/// Whether a change could be saved now: the name is not blank and nothing is loading or saving.
	var isReadyToSave: Bool {
		!trimmedName.isEmpty && !isBusy && !isLoading
	}

	/// The name as it is saved, without the spaces and line breaks around it; spaces alone are no change to it.
	private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

	/// Image identity decides equality here: every newly picked or reframed picture gets a new identifier.
	private var parameters: AddPersonParameters {
		AddPersonParameters(
			name: trimmedName, dayOfBirth: birthday, timeOfBirth: birthday, appImage: appImage, widgetImage: widgetImage,
			isOnWidget: isOnWidget, celebratesBirthdays: celebratesBirthdays, originalImage: originalImage)
	}

	private func updateBirthday(day: Date, hour: Int, minute: Int, second: Int) {
		guard let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: day) else { return }
		birthday = clamped(date)
	}

	/// Keeps the birthday in the past; an unknown time stays at midnight.
	private func clamped(_ date: Date) -> Date {
		min(date, birthTimeIsKnown ? maximumBirthday : Calendar.current.startOfDay(for: maximumBirthday))
	}

	// MARK: - Photo

	/// The photo both pictures are framed from: the original kept since it was picked, else, for a photo picked before
	/// originals were kept, the main picture itself, whose discarded pixels are gone. Nil without a main picture.
	var framingSource: PersonImage? {
		guard let appImage else { return nil }
		return originalImage ?? appImage
	}

	/// The region of `framingSource` the main picture shows: all of it when the main picture is its own original.
	var mainCrop: PhotoCrop? {
		guard let appImage else { return nil }
		guard let originalImage, originalImage.id != appImage.id else { return .whole }
		return appImage.crop
	}

	/// Replaces the photo with a newly picked one, kept whole as the original, and derives the widget picture from the
	/// main picture's centred square.
	func setMainPhoto(_ framed: FramedPhoto) {
		originalImage = PersonImage(uiImage: framed.source)
		appImage = PersonImage(uiImage: framed.picture, crop: framed.crop)
		deriveWidgetPicture(from: framed)
	}

	/// Replaces the main picture with a new framing of `framingSource`. A widget picture derived from the photo in this
	/// session follows the new framing; one the person framed separately, or one saved earlier, stays as it is, its region
	/// of the original unchanged.
	func reframeMainPhoto(_ framed: FramedPhoto) {
		keepMainPictureAsOriginal()
		appImage = PersonImage(uiImage: framed.picture, crop: framed.crop)
		if widgetPictureIsDerived { deriveWidgetPicture(from: framed) }
	}

	/// Removes the photo together with both pictures framed from it.
	func removeMainPhoto() {
		appImage = nil
		widgetImage = nil
		originalImage = nil
		widgetPictureIsDerived = false
		analytics.track(.photoRemoved)
	}

	/// Replaces only the widget picture with a new framing of `framingSource`.
	func setWidgetPhoto(_ framed: FramedPhoto) {
		keepMainPictureAsOriginal()
		widgetImage = PersonImage(uiImage: framed.picture, crop: framed.crop)
		widgetPictureIsDerived = false
	}

	/// The photo both pictures are framed from at its full size, loaded from storage when it was saved earlier; `nil`
	/// without a main picture or on failure.
	func loadFramingSource() async -> UIImage? {
		guard let source = framingSource else { return nil }
		if let image = source.uiImage { return image }
		do {
			let loaded = try await loadOriginal(source)
			// The photo may have been replaced or removed while loading; a stale image must not be framed.
			return framingSource?.id == source.id ? loaded : nil
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
			analytics.report(AnalyticsFailure(operation: "load_photo", error: error))
		}
		return nil
	}

	/// A main picture saved before originals were kept becomes the original the first time a picture is framed from it,
	/// so it stays stored, whole, once the main picture is replaced; framing never crops a framed picture again.
	private func keepMainPictureAsOriginal() {
		guard originalImage == nil, let appImage else { return }
		originalImage = PersonImage(id: appImage.id, uiImage: appImage.uiImage)
	}

	/// Renders the widget picture from the original: the centred square of the main picture's region.
	private func deriveWidgetPicture(from framed: FramedPhoto) {
		let crop = WidgetPictureDeriver.crop(centredIn: framed.crop, ofPhotoSized: CropGeometry.pixelSize(of: framed.source))
		let picture = framed.source.cropped(to: crop).downsized(maxPixelSide: WidgetPictureDeriver.maxPixelSide)
		widgetImage = PersonImage(uiImage: picture, crop: crop)
		widgetPictureIsDerived = true
	}

	/// The widget picture the person's page shows while there is no main photo, as `PersonPictureCandidates` picks it;
	/// `nil` without one or when it does not load, which the page answers silently with the monogram.
	func loadWidgetPicture() async -> UIImage? {
		guard let widgetImage else { return nil }
		if let image = widgetImage.uiImage { return image }
		let loaded = try? await loadImage(widgetImage)
		// The picture may have been replaced or removed while loading.
		return self.widgetImage?.id == widgetImage.id ? loaded : nil
	}

	func load() async {
		guard isLoading else { return }
		defer {
			baseline = parameters
			isLoading = false
		}
		guard person == nil else { return }
		do {
			isOnWidget = try await fetchUseCase.fetchWidgetPersons().count < Constants.widgetPeopleLimit
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
			analytics.report(AnalyticsFailure(operation: "load_widget_people", error: error))
		}
	}

	func save() async {
		guard isDirty, !isBusy, !isLoading else { return }
		guard !trimmedName.isEmpty else {
			error = SceneError(CoreError.noNameValue)
			return
		}
		isBusy = true
		defer { isBusy = false }
		do {
			if isOnWidget {
				let pinned = try await fetchUseCase.fetchWidgetPersons()
				guard pinned.filter({ $0.id != person?.id }).count < Constants.widgetPeopleLimit else {
					throw CoreError.widgetPeopleLimitReached
				}
			}
			let saved: Person
			if let person {
				saved = try await editUseCase.edit(person: person, with: parameters)
			} else {
				saved = try await addUseCase.add(parameters: parameters)
			}
			// The draft now matches what is stored, so the same change cannot be saved twice.
			baseline = parameters
			onMutation(.saved(saved))
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
			// A seventh pinned person is a rule the alert explains, not a failure.
			if error as? CoreError != .widgetPeopleLimitReached {
				analytics.report(AnalyticsFailure(operation: "save_person", error: error))
			}
		}
	}

	func remove() async {
		guard let person, !isBusy else { return }
		isBusy = true
		defer { isBusy = false }
		do {
			try await removeUseCase.remove(person: person)
			onMutation(.removed(person))
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
			analytics.report(AnalyticsFailure(operation: "remove_person", error: error))
		}
	}
}
