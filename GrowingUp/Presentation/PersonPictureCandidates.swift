import Core

/// The one rule for which picture shows a person, in their mosaic tile and on their page alike: the portrait app photo,
/// else the square widget photo; a person neither of them loads for shows their monogram.
enum PersonPictureCandidates {
	/// The stored pictures to try in turn, best first, each once.
	static func ids(of person: Person) -> [UUID] {
		var ids: [UUID] = []
		for id in [person.appPicId, person.widgetPicId].compactMap({ $0 }) where !ids.contains(id) {
			ids.append(id)
		}
		return ids
	}
}
