/// A value an analytics property can carry. Only these scalar kinds exist, so free text such as a person's name cannot
/// slip into an event by accident.
enum AnalyticsValue: Equatable {
	case string(String)
	case int(Int)
	case bool(Bool)

	/// The value as the SDKs accept it.
	var anyValue: Any {
		switch self {
		case .string(let value): value
		case .int(let value): value
		case .bool(let value): value
		}
	}
}
