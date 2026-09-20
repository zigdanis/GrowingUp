import Core

final class CancelledSaveGateway: PersonsGatewaySpy {
	override func add(parameters: AddPersonParameters) async throws -> Person { throw CancellationError() }
}
