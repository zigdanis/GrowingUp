import Core
import SwiftUI

struct PersonCell: View {
	let person: WidgetPerson
	let date: Date
	let compact: Bool

	private var ageText: String {
		AgeCalculator.ageString(for: AgeCalculator.ageComponents(from: person.birthday, to: date))
	}

	var body: some View {
		VStack(spacing: 6) {
			face.frame(width: compact ? 56 : 48, height: compact ? 56 : 48).clipShape(Circle())
			Text(person.name).font(.caption).fontWeight(.semibold).lineLimit(1)
			Text(ageText).font(.caption2).foregroundStyle(.secondary)
				.multilineTextAlignment(.center).lineLimit(compact ? 4 : 3).minimumScaleFactor(0.7)
		}
		.padding(.horizontal, 4)
	}

	@ViewBuilder private var face: some View {
		if let image = person.image {
			Image(uiImage: image).resizable().scaledToFill()
		} else {
			Image("face").resizable().scaledToFit().foregroundStyle(.secondary)
		}
	}
}
