import Core
import SwiftUI

struct BirthdayInfoView: View {
	let status: BirthdayStatus
	@Environment(\.locale) private var locale
	@Environment(\.calendar) private var calendar

	var body: some View {
		VStack(spacing: 8) {
			Text(status.isToday ? LocalizedStringKey("Happy birthday!") : LocalizedStringKey("Until birthday"))
				.font(.headline)
			if !status.isToday {
				Text(countdown).font(.title3).monospacedDigit()
					.accessibilityIdentifier("birthday.countdown")
			}
		}
		.padding(20)
		.accessibilityIdentifier("birthday.info")
	}

	private var countdown: String {
		let formatter = DateComponentsFormatter()
		var localizedCalendar = calendar
		localizedCalendar.locale = locale
		formatter.calendar = localizedCalendar
		formatter.unitsStyle = .full
		if status.countdown.day != nil {
			formatter.allowedUnits = .day
		} else if status.countdown.hour != nil {
			formatter.allowedUnits = .hour
		} else if status.countdown.minute != nil {
			formatter.allowedUnits = .minute
		} else {
			formatter.allowedUnits = .second
		}
		formatter.maximumUnitCount = 1
		return formatter.string(from: status.countdown) ?? ""
	}
}
