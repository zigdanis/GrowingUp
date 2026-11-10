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
	/// The app asked iOS for the App Store rating sheet; iOS alone decides whether it shows.
	case reviewPromptRequested(
		activeDays: Int, daysSinceFirstActive: Int, viewerVisits: Int, peopleWithPhotoCount: Int, requestNumber: Int)
	/// The person chose to export a library that store recovery preserved, and the archive is ready to share.
	case preservedDataExported
	/// "Export all data" wrote the whole library to a file, which is ready in the share sheet.
	case dataExported(peopleCount: Int)
	/// A backup was restored; only people the library lacked were added.
	case dataRestored(
		source: BackupRestoreSource, peopleAdded: Int, peopleAlreadyPresent: Int, peopleOverLimit: Int, intoEmptyLibrary: Bool)
	/// The iCloud backup was switched on or off in Settings.
	case iCloudBackupToggled(isOn: Bool)
	/// The mosaic shows the Home Screen widget hint on this launch; `shownLaunches` counts this one.
	case widgetHintShown(shownLaunches: Int)
	/// The hint was tapped and the widget guide opened.
	case widgetHintOpened(shownLaunches: Int)
	/// × closed the hint.
	case widgetHintDismissed(shownLaunches: Int)
	/// The launch's first load of the mosaic's tile pictures completed: how many came ready from the thumbnail cache,
	/// were decoded from the full-size picture or show a monogram, and how long the tiles waited.
	case mosaicPicturesLoaded(peopleCount: Int, cachedCount: Int, decodedCount: Int, monogramCount: Int, durationMs: Int)

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
		case .reviewPromptRequested: "review_prompt_requested"
		case .preservedDataExported: "preserved_data_exported"
		case .dataExported: "data_exported"
		case .dataRestored: "data_restored"
		case .iCloudBackupToggled: "icloud_backup_toggled"
		case .widgetHintShown: "widget_hint_shown"
		case .widgetHintOpened: "widget_hint_opened"
		case .widgetHintDismissed: "widget_hint_dismissed"
		case .mosaicPicturesLoaded: "mosaic_pictures_loaded"
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
		case .photoRemoved, .photoReframed, .widgetPictureFramed, .preservedDataExported:
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
		case .personRemoved(let peopleCount), .peopleReordered(let peopleCount), .dataExported(let peopleCount):
			["people_count": .int(peopleCount)]
		case .dataRestored(let source, let peopleAdded, let peopleAlreadyPresent, let peopleOverLimit, let intoEmptyLibrary):
			[
				"source": .string(source.rawValue),
				"people_added": .int(peopleAdded),
				"people_already_present": .int(peopleAlreadyPresent),
				"people_over_limit": .int(peopleOverLimit),
				"into_empty_library": .bool(intoEmptyLibrary)
			]
		case .iCloudBackupToggled(let isOn):
			["is_on": .bool(isOn)]
		case .reviewPromptRequested(let activeDays, let daysSinceFirstActive, let viewerVisits, let peopleWithPhotoCount, let requestNumber):
			[
				"active_days": .int(activeDays),
				"days_since_first_active": .int(daysSinceFirstActive),
				"viewer_visits": .int(viewerVisits),
				"people_with_photo_count": .int(peopleWithPhotoCount),
				"request_number": .int(requestNumber)
			]
		case .widgetHintShown(let shownLaunches), .widgetHintOpened(let shownLaunches), .widgetHintDismissed(let shownLaunches):
			["shown_launches": .int(shownLaunches)]
		case .mosaicPicturesLoaded(let peopleCount, let cachedCount, let decodedCount, let monogramCount, let durationMs):
			[
				"people_count": .int(peopleCount),
				"cached_count": .int(cachedCount),
				"decoded_count": .int(decodedCount),
				"monogram_count": .int(monogramCount),
				"duration_ms": .int(durationMs)
			]
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
