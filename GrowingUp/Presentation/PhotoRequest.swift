import Foundation

/// A request to pick or capture a new main photo from `source`.
struct PhotoRequest: Identifiable {
	let id = UUID()
	let source: ImageCaptureSource
}
