public final class FetchPersonsUseCaseImplementation: FetchPersonsUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func fetchPersons() async throws -> [Person] {
		try await personsGateway.fetchPersons()
	}

	public func fetchWidgetPersons() async throws -> [Person] {
		try await personsGateway.fetchWidgetPersons()
	}
}
