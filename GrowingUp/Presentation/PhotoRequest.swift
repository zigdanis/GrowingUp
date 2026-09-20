import Foundation

struct PhotoRequest: Identifiable {
	let id = UUID()
	let isWidget: Bool
	let source: ImageCaptureSource
}
