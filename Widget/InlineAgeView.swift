import Core
import SwiftUI

/// One line above the clock, with a cake on the birthday.
struct InlineAgeView: View {
	let text: LockScreenText

	var body: some View {
		if text.isBirthday {
			Label(text.inline, systemImage: "birthday.cake")
		} else {
			Text(text.inline)
		}
	}
}
