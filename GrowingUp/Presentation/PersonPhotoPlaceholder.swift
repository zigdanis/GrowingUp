import SwiftUI

/// What a person page shows in place of a missing photo: an indigo glow and, optionally, a shrug.
struct PersonPhotoPlaceholder: View {
	var showsShrug = true

	var body: some View {
		ZStack {
			LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
			if showsShrug {
				Text("🤷").font(.system(size: 100))
			}
		}
	}
}
