public final class EditPersonUseCaseImplementation: EditPersonUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func edit(person: Person, with parameters: AddPersonParameters) async throws -> Person {
		try await personsGateway.edit(person: person, with: parameters)
	}
}
