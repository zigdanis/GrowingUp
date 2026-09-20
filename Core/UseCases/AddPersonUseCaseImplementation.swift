public final class AddPersonUseCaseImplementation: AddPersonUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func add(parameters: AddPersonParameters) async throws -> Person {
		try await personsGateway.add(parameters: parameters)
	}
}
