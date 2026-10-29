import Core

/// Facts attached to every event and crash report: how many people the app holds. Counts only, never the people.
struct AnalyticsContext: Equatable {
	var peopleCount: Int
	var widgetPeopleCount: Int

	var properties: [String: AnalyticsValue] {
		["people_count": .int(peopleCount), "widget_people_count": .int(widgetPeopleCount)]
	}
}

extension AnalyticsContext {
	/// The counts of `people`, everyone the store holds.
	init(people: [Person]) {
		self.init(peopleCount: people.count, widgetPeopleCount: people.filter(\.isOnWidget).count)
	}
}
