import SwiftUI

/// Asks before the edited person is removed: on iPad as a dialog popping over the Remove button, elsewhere as an alert.
///
/// The scene and the Remove button both carry it; only the one matching the device shows.
struct RemovalConfirmation: ViewModifier {
	@Bindable var mode: PersonEditModePresenter
	/// Whether it sits on the Remove button, whose dialog iPad shows; the scene's carries the alert.
	let isOnButton: Bool

	func body(content: Content) -> some View {
		let isPresented = Binding(
			get: { mode.isConfirmingRemoval && isOnButton == (UIDevice.current.userInterfaceIdiom == .pad) },
			set: { mode.isConfirmingRemoval = $0 })
		if isOnButton {
			content.confirmationDialog(mode.removalTitle, isPresented: isPresented, titleVisibility: .visible) {
				actions
			} message: {
				message
			}
		} else {
			content.alert(mode.removalTitle, isPresented: isPresented) {
				actions
			} message: {
				message
			}
		}
	}

	@ViewBuilder private var actions: some View {
		Button("Remove", role: .destructive) { Task { await mode.remove() } }
		Button("Cancel", role: .cancel) {}
	}

	private var message: some View {
		Text("Their photo, birthday and settings will disappear from the app and the widget.")
	}
}
