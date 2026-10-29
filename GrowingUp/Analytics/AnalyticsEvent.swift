/// Every product event the app records. Names are snake_case; properties never carry a person's name, birthday, age or
/// photo, only categories and counts.
enum AnalyticsEvent: Equatable {
	case personViewed(source: PersonViewSource)
	case widgetLinkOpened(target: WidgetLinkTarget)
	case personEditorOpened(isNewPerson: Bool, source: PersonEditorSource)
	case personEditorClosed(isNewPerson: Bool, outcome: PersonEditorOutcome)
	case birthdayPickerOpened(PersonEditPopover)
	case photoPicked(source: ImageCaptureSource)
	case photoRemoved
	case photoReframed
	case widgetPictureFramed
	case personSaved(PersonSavedProperties)
	case personRemoved(peopleCount: Int)
	case peopleReordered(peopleCount: Int)

	var name: String {
		switch self {
		case .personViewed: "person_viewed"
		case .widgetLinkOpened: "widget_link_opened"
		case .personEditorOpened: "person_editor_opened"
		case .personEditorClosed: "person_editor_closed"
		case .birthdayPickerOpened: "birthday_picker_opened"
		case .photoPicked: "photo_picked"
		case .photoRemoved: "photo_removed"
		case .photoReframed: "photo_reframed"
		case .widgetPictureFramed: "widget_picture_framed"
		case .personSaved: "person_saved"
		case .personRemoved: "person_removed"
		case .peopleReordered: "people_reordered"
		}
	}

	var properties: [String: AnalyticsValue] {
		switch self {
		case .personViewed(let source):
			["source": .string(source.rawValue)]
		case .widgetLinkOpened(let target):
			["target": .string(target.rawValue)]
		case .personEditorOpened(let isNewPerson, let source):
			["mode": Self.mode(isNewPerson), "source": .string(source.rawValue)]
		case .personEditorClosed(let isNewPerson, let outcome):
			["mode": Self.mode(isNewPerson), "outcome": .string(outcome.rawValue)]
		case .birthdayPickerOpened(let popover):
			["field": .string(Self.field(popover))]
		case .photoPicked(let source):
			["source": .string(Self.source(source))]
		case .photoRemoved, .photoReframed, .widgetPictureFramed:
			[:]
		case .personSaved(let person):
			[
				"mode": Self.mode(person.isNewPerson),
				"has_photo": .bool(person.hasPhoto),
				"photo_changed": .bool(person.photoChanged),
				"has_birth_time": .bool(person.hasBirthTime),
				"on_widget": .bool(person.isOnWidget),
				"celebrates_birthdays": .bool(person.celebratesBirthdays),
				"people_count": .int(person.peopleCount),
				"widget_people_count": .int(person.widgetPeopleCount)
			]
		case .personRemoved(let peopleCount), .peopleReordered(let peopleCount):
			["people_count": .int(peopleCount)]
		}
	}

	private static func mode(_ isNewPerson: Bool) -> AnalyticsValue {
		.string(isNewPerson ? "create" : "edit")
	}

	private static func field(_ popover: PersonEditPopover) -> String {
		switch popover {
		case .date: "date"
		case .time: "time"
		}
	}

	private static func source(_ source: ImageCaptureSource) -> String {
		switch source {
		case .camera: "camera"
		case .photos: "photos"
		}
	}
}
