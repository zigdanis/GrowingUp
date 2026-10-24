import Foundation

public protocol ReorderPersonsUseCase {
	/// Stores `ids` as the order of the mosaic, the viewer's pages and the widgets.
	func reorder(_ ids: [UUID]) async throws
}
