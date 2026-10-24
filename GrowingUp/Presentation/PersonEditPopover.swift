/// The centred card the in-place edit mode shows over a dim layer, one at a time.
enum PersonEditPopover: Equatable {
	/// The calendar for the day of birth.
	case date
	/// The hour and minute wheels for the time of birth.
	case time
}
