import Core
import Foundation

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
