import Core
import Observation
import UIKit

struct SceneError: Identifiable, Equatable {
	let id = UUID()
	let title: String
	let message: String

	init(_ error: Error) {
		let coreError = error as? CoreError
		title = coreError?.title ?? String(localized: "Error")
		message = coreError?.message ?? error.localizedDescription
	}
}

enum PersonMutation {
	case saved(Person)
	case removed(Person)
}

@MainActor
@Observable
final class PersonEditorPresenter: Identifiable {
	let id = UUID()
	let person: Person?
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
	private let onCancel: () -> Void

	init(
		person: Person?, addUseCase: AddPersonUseCase, editUseCase: EditPersonUseCase,
		removeUseCase: RemovePersonUseCase, fetchUseCase: FetchPersonsUseCase,
		now: Date = Date(), onMutation: @escaping (PersonMutation) -> Void, onCancel: @escaping () -> Void
	) {
		self.person = person
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
		self.onCancel = onCancel
	}

	func load() async {
		guard isLoading else { return }
		defer { isLoading = false }
		guard person == nil else { return }
		do {
			isOnWidget = try await fetchUseCase.fetchWidgetPersons().count < 3
		} catch is CancellationError {
		} catch {
			self.error = SceneError(error)
		}
	}

	func save() async {
		guard !isBusy, !isLoading else { return }
		guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			error = SceneError(CoreError.noNameValue)
			return
		}
		isBusy = true
		defer { isBusy = false }
		do {
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

	func cancel() {
		guard !isBusy else { return }
		onCancel()
	}
}
