import SwiftUI
import UIKit

/// The system share sheet for one file: Save to Files, AirDrop, Mail and the rest, whichever the person picks. It
/// reports when it closes, so the file can be removed.
struct ActivityShareSheet: UIViewControllerRepresentable {
	let url: URL
	let onComplete: () -> Void

	func makeUIViewController(context: Context) -> UIActivityViewController {
		let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
		controller.completionWithItemsHandler = { _, _, _, _ in onComplete() }
		return controller
	}

	func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
