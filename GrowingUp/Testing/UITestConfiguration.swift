import Foundation

struct UITestConfiguration: Codable {
	static let environmentKey = "GROWINGUP_UI_TEST_CONFIGURATION"

	let identifier: UUID
	let resetStore: Bool
	let seed: UITestSeed
	let failNextSave: Bool
	let appearance: UITestAppearance

	var encoded: String {
		do {
			return try JSONEncoder().encode(self).base64EncodedString()
		} catch {
			preconditionFailure("Failed to encode UI test configuration: \(error)")
		}
	}

	func forRelaunch() -> Self {
		Self(identifier: identifier, resetStore: false, seed: seed, failNextSave: false, appearance: appearance)
	}

	static func decode(_ encoded: String) throws -> Self {
		guard let data = Data(base64Encoded: encoded) else { throw CocoaError(.coderReadCorrupt) }
		return try JSONDecoder().decode(Self.self, from: data)
	}
}
