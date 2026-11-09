/// Whether the iCloud backup has somewhere to go.
enum ICloudBackupAvailability: Equatable {
	case checking
	case available
	/// No iCloud account, iCloud Drive is off for the app, or the app has no iCloud container.
	case unavailable
}
