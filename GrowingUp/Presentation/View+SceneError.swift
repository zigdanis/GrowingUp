import SwiftUI

extension View {
	func sceneError(_ error: Binding<SceneError?>) -> some View {
		alert(
			error.wrappedValue?.title ?? "",
			isPresented: Binding(
				get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } }
			)
		) {
			Button("OK", role: .cancel) { error.wrappedValue = nil }
		} message: {
			Text(error.wrappedValue?.message ?? "")
		}
	}
}
