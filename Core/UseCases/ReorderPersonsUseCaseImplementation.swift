import Foundation

public final class ReorderPersonsUseCaseImplementation: ReorderPersonsUseCase {
	let personsGateway: PersonsGateway

	public init(personsGateway: PersonsGateway) {
		self.personsGateway = personsGateway
	}

	public func reorder(_ ids: [UUID]) async throws {
		try await personsGateway.reorder(ids)
	}
}
