public final class RemovePersonUseCaseImplementation: RemovePersonUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func remove(person: Person) async throws {
		try await personsGateway.remove(person: person)
	}
}
