import SwiftUI

/// Bridges the limited-library picker into SwiftUI.
struct LimitedLibraryPickerPresenter: UIViewControllerRepresentable {
	@Binding var isPresented: Bool
	let present: (UIViewController) -> Void

	func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

	func updateUIViewController(_ viewController: UIViewController, context: Context) {
		guard isPresented else { return }
		DispatchQueue.main.async {
			present(viewController)
			isPresented = false
		}
	}
}
