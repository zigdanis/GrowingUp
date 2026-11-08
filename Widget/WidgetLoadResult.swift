/// What a widget read from the shared store.
///
/// Only `nobodyPinned` is a confirmed absence that invites adding someone. `unavailable` means the store could not be
/// read, for example before the first unlock after a restart, so whether anyone is pinned is unknown.
enum WidgetLoadResult<Value> {
	case loaded(Value)
	case nobodyPinned
	case unavailable

	/// The loaded value, or `nil` in both states without people.
	var value: Value? {
		if case .loaded(let value) = self { value } else { nil }
	}

	func map<NewValue>(_ transform: (Value) -> NewValue) -> WidgetLoadResult<NewValue> {
		switch self {
		case .loaded(let value): .loaded(transform(value))
		case .nobodyPinned: .nobodyPinned
		case .unavailable: .unavailable
		}
	}
}
