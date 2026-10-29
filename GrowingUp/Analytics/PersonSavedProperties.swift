import Core
import Foundation

/// What a saved person looks like, without their name, birthday, age or photo: only which fields are filled and how
/// many people the app holds afterwards.
struct PersonSavedProperties: Equatable {
	var isNewPerson: Bool
	var hasPhoto: Bool
	var photoChanged: Bool
	var hasBirthTime: Bool
	var isOnWidget: Bool
	var celebratesBirthdays: Bool
	var peopleCount: Int
	var widgetPeopleCount: Int

	/// The facts of `saved`, compared with `previous`, the person as stored before, if any; `people` are everyone after
	/// the save.
	init(saved: Person, previous: Person?, people: [Person], calendar: Calendar = .current) {
		isNewPerson = previous == nil
		// A widget picture alone stands in for the photo on the person's page, so it counts as one.
		hasPhoto = saved.appPicId != nil || saved.widgetPicId != nil
		photoChanged = saved.appPicId != previous?.appPicId || saved.widgetPicId != previous?.widgetPicId
		// An unknown time of birth is stored as local midnight; see `PersonEditorPresenter.hasBirthTime`.
		hasBirthTime = saved.birthday != calendar.startOfDay(for: saved.birthday)
		isOnWidget = saved.isOnWidget
		celebratesBirthdays = saved.celebratesBirthdays
		peopleCount = people.count
		widgetPeopleCount = people.filter(\.isOnWidget).count
	}
}
