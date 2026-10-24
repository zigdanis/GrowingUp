#if DEBUG
	import Core
	import Foundation

	final class UITestFailureGateway: PersonsGateway {
		let base: PersonsGateway
		var failNextSave: Bool

		init(base: PersonsGateway, failNextSave: Bool) {
			self.base = base
			self.failNextSave = failNextSave
		}

		private func checkFailure() throws {
			if failNextSave {
				failNextSave = false
				throw CoreError.coreDataSaveFailed
			}
		}

		func add(parameters: AddPersonParameters) async throws -> Person {
			try checkFailure()
			return try await base.add(parameters: parameters)
		}

		func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person {
			try checkFailure()
			return try await base.edit(person: person, with: parameters)
		}

		func reorder(_ ids: [UUID]) async throws {
			try checkFailure()
			try await base.reorder(ids)
		}

		func remove(person: Person) async throws { try await base.remove(person: person) }
		func fetchPersons() async throws -> [Person] { try await base.fetchPersons() }
		func fetchWidgetPersons() async throws -> [Person] { try await base.fetchWidgetPersons() }
	}
#endif
