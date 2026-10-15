import Core
import Observation
import UIKit

@MainActor
@Observable
final class PersonEditorPresenter: Identifiable {
	let id = UUID()
	let person: Person?
	let maximumBirthday: Date
	let loadImage: (PersonImage) async throws -> UIImage
	let photoFixtures: [UIImage]?
	var name: String
	private(set) var birthday: Date
	var isOnWidget: Bool
	var celebratesBirthdays: Bool
	var appImage: PersonImage?
	var widgetImage: PersonImage?
	var error: SceneError?
	private(set) var isBusy = false
	private(set) var isLoading = true
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
		photoFixtures: [UIImage]? = nil, onMutation: @escaping (PersonMutation) -> Void
	) {
		let calendar = Calendar.current
		let birthday = person?.birthday ?? calendar.startOfDay(for: now)
		self.person = person
		maximumBirthday = now
		self.loadImage = loadImage
		self.photoFixtures = photoFixtures
		name = person?.name ?? ""
		self.birthday = birthday
		birthTimeIsKnown = birthday != calendar.startOfDay(for: birthday)
		isOnWidget = person?.isOnWidget ?? false
		celebratesBirthdays = person?.celebratesBirthdays ?? true
		appImage = PersonImage(id: person?.appPicId)
		widgetImage = PersonImage(id: person?.widgetPicId)
		self.addUseCase = addUseCase
		self.editUseCase = editUseCase
		self.removeUseCase = removeUseCase
		self.fetchUseCase = fetchUseCase
		self.onMutation = onMutation
	}

	/// Whether the time of birth is known.
	///
	/// `CoreDataPerson.birthdate` is a single date without a "has time" flag, so an unknown time is stored as
	/// local midnight (00:00:00) and the editor shows no time. The toggle loads as on only when the stored time
	/// of day is not exactly midnight. Turning it on keeps the current time, midnight for an unknown one, until
	/// a time is picked; a picked time stores its hour and minute with zero seconds. Turning it off resets the
	/// time to midnight. A birth time explicitly picked as 00:00 therefore reopens with the toggle off.
	var hasBirthTime: Bool {
		get { birthTimeIsKnown }
		set {
			birthTimeIsKnown = newValue
			if !newValue { birthday = clamped(Calendar.current.startOfDay(for: birthday)) }
		}
	}

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

	var canSave: Bool {
		isDirty && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy && !isLoading
	}

	/// Image identity decides equality here: every newly picked or reframed picture gets a new identifier.
	private var parameters: AddPersonParameters {
		AddPersonParameters(
			name: name, dayOfBirth: birthday, timeOfBirth: birthday, appImage: appImage, widgetImage: widgetImage,
			isOnWidget: isOnWidget, celebratesBirthdays: celebratesBirthdays)
	}

	private func updateBirthday(day: Date, hour: Int, minute: Int, second: Int) {
		guard let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: day) else { return }
		birthday = clamped(date)
	}

	/// Keeps the birthday in the past; an unknown time stays at midnight.
	private func clamped(_ date: Date) -> Date {
		min(date, birthTimeIsKnown ? maximumBirthday : Calendar.current.startOfDay(for: maximumBirthday))
	}

	/// Replaces the main photo and derives the widget picture from its centered square.
	func setMainPhoto(_ image: UIImage) {
		appImage = PersonImage(uiImage: image)
		widgetImage = PersonImage(uiImage: WidgetPictureDeriver.derive(from: image))
	}

	/// Removes the main photo together with the widget picture that belongs to it.
	func removeMainPhoto() {
		appImage = nil
		widgetImage = nil
	}

	/// Replaces only the widget picture, for example with a reframed crop of the main photo.
	func setWidgetPhoto(_ image: UIImage) {
		widgetImage = PersonImage(uiImage: image)
	}

	/// The full main photo, loaded from storage when it was saved earlier; `nil` without a photo or on failure.
	func loadMainPhoto() async -> UIImage? {
		guard let appImage else { return nil }
		if let image = appImage.uiImage { return image }
		do {
			return try await loadImage(appImage)
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
		}
		return nil
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
		}
	}

	func save() async {
		guard isDirty, !isBusy, !isLoading else { return }
		guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
			onMutation(.saved(saved))
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
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
		}
	}

}
