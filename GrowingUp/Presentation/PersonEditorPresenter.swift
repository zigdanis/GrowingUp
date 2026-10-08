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
	var birthday: Date
	var isOnWidget: Bool
	var appImage: PersonImage?
	var widgetImage: PersonImage?
	var error: SceneError?
	private(set) var isBusy = false
	private(set) var isLoading = true
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
		self.person = person
		maximumBirthday = now
		self.loadImage = loadImage
		self.photoFixtures = photoFixtures
		name = person?.name ?? ""
		birthday = person?.birthday ?? now
		isOnWidget = person?.isOnWidget ?? false
		appImage = PersonImage(id: person?.appPicId)
		widgetImage = PersonImage(id: person?.widgetPicId)
		self.addUseCase = addUseCase
		self.editUseCase = editUseCase
		self.removeUseCase = removeUseCase
		self.fetchUseCase = fetchUseCase
		self.onMutation = onMutation
	}

	var dayOfBirth: Date {
		get { birthday }
		set { updateBirthday(day: newValue, time: birthday) }
	}

	var timeOfBirth: Date {
		get { birthday }
		set { updateBirthday(day: birthday, time: newValue) }
	}

	var hasChanges: Bool {
		guard let person else { return true }
		return name != person.name || birthday != person.birthday || isOnWidget != person.isOnWidget
			|| appImage != PersonImage(id: person.appPicId) || widgetImage != PersonImage(id: person.widgetPicId)
	}

	var canSave: Bool { hasChanges && !isBusy && !isLoading }

	private func updateBirthday(day: Date, time: Date) {
		let calendar = Calendar.current
		guard
			let date = calendar.date(
				bySettingHour: calendar.component(.hour, from: time),
				minute: calendar.component(.minute, from: time),
				second: calendar.component(.second, from: time), of: day)
		else { return }
		birthday = min(date, maximumBirthday)
	}

	func load() async {
		guard isLoading else { return }
		defer { isLoading = false }
		guard person == nil else { return }
		do {
			isOnWidget = try await fetchUseCase.fetchWidgetPersons().count < Constants.widgetPeopleLimit
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
		}
	}

	func save() async {
		guard canSave else { return }
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
			let parameters = AddPersonParameters(
				name: name, dayOfBirth: birthday, timeOfBirth: birthday,
				appImage: appImage, widgetImage: widgetImage, isOnWidget: isOnWidget)
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
