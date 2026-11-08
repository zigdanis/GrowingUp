import Foundation

/// What a backup's `backup.json` holds: every person the app stores and the photo files their pictures are kept in,
/// with when, by which version and on which kind of device it was written. The photos' bytes are files next to it.
public struct BackupDocument: Codable, Equatable, Sendable {
	public static let formatName = "growingup-backup"
	/// The newest format this version reads; a backup in a newer one asks for an update instead.
	public static let currentFormatVersion = 1

	public var format = Self.formatName
	public var formatVersion = Self.currentFormatVersion
	public var createdAt: Date
	/// The version and build that wrote it, such as `3.2 (50)`.
	public var appVersion: String
	/// `UIDevice.model`, such as `iPhone`; never the device's name.
	public var deviceModel: String
	/// In mosaic order.
	public var people: [BackupPerson]
	public var photos: [BackupPhoto]

	public init(createdAt: Date, appVersion: String, deviceModel: String, people: [BackupPerson], photos: [BackupPhoto]) {
		self.createdAt = createdAt
		self.appVersion = appVersion
		self.deviceModel = deviceModel
		self.people = people
		self.photos = photos
	}

	public var isEmpty: Bool { people.isEmpty }
}
