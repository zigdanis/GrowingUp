import SwiftUI

/// A headline and a short message in place of the mosaic, with the floating button below it as the one way on: the empty
/// mosaic's invitation above "Add person", or, while no read of the people has succeeded, the notice above "Try Again"
/// that they are unknown rather than gone. Below the message, in the same column, may come an accessory, such as the
/// offer to restore a backup from iCloud.
///
/// It sits centred in the space above the button; when the largest text sizes leave it no room, as on an iPhone Duo, it
/// scrolls rather than truncating.
struct PeopleNotice<Accessory: View>: View {
	let title: LocalizedStringKey
	let message: LocalizedStringKey
	/// The prefix of the accessibility identifiers of the headline and the message.
	let identifier: String
	let accessory: Accessory

	init(title: LocalizedStringKey, message: LocalizedStringKey, identifier: String, @ViewBuilder accessory: () -> Accessory) {
		self.title = title
		self.message = message
		self.identifier = identifier
		self.accessory = accessory()
	}

	/// The notice with `accessory` below its message.
	func accessory<Other: View>(@ViewBuilder _ accessory: () -> Other) -> PeopleNotice<Other> {
		PeopleNotice<Other>(title: title, message: message, identifier: identifier, accessory: accessory)
	}

	var body: some View {
		ViewThatFits(in: .vertical) {
			notice
			ScrollView { notice }
				.scrollBounceBehavior(.basedOnSize)
		}
	}

	private var notice: some View {
		VStack(spacing: 12) {
			Text(title)
				.font(.title.bold())
				.accessibilityAddTraits(.isHeader)
				.accessibilityIdentifier("\(identifier).title")
			Text(message)
				.font(.body)
				.foregroundStyle(.secondary)
				.accessibilityIdentifier("\(identifier).message")
			accessory
		}
		.multilineTextAlignment(.center)
		.padding(32)
		// Wider than any iPhone, such as an iPhone Duo, the notice stays a readable column.
		.frame(maxWidth: 440)
		.frame(maxWidth: .infinity)
	}
}

extension PeopleNotice where Accessory == EmptyView {
	init(title: LocalizedStringKey, message: LocalizedStringKey, identifier: String) {
		self.init(title: title, message: message, identifier: identifier) { EmptyView() }
	}

	/// The empty mosaic's short invitation.
	static var invitation: PeopleNotice {
		PeopleNotice(
			title: "Who is growing up?", message: "Add someone you love and watch their age count up, live to the second.",
			identifier: "people.invitation")
	}

	/// The people could not be read, so nothing invites a first person as if there were none.
	static var unavailable: PeopleNotice {
		PeopleNotice(
			title: "Couldn't load your people", message: "The app couldn't read them just now. Try again in a moment.",
			identifier: "people.unavailable")
	}
}
