extension Dictionary where Key == String, Value == AnalyticsValue {
	/// The properties as the SDKs accept them.
	var anyValues: [String: Any] {
		mapValues(\.anyValue)
	}
}
