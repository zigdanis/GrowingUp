import Foundation

/// A person as a backup keeps them: everything the store holds about them, with their pictures by identifier, which
/// `BackupDocument.photos` lists with the files that hold them.
public struct BackupPerson: Codable, Equatable, Sendable {
	public var id: UUID
	public var name: String
	/// The day and time of birth, as the store keeps it.
	public var birthday: Date
	public var createdDate: Date
	public var displayOrder: Int
	public var isOnWidget: Bool
	public var celebratesBirthdays: Bool
	public var appPicId: UUID?
	public var widgetPicId: UUID?
	public var originalPicId: UUID?
	public var appPicCrop: PhotoCrop?
	public var widgetPicCrop: PhotoCrop?

	public init(_ person: Person) {
		id = person.id
		name = person.name
		birthday = person.birthday
		createdDate = person.createdDate
		displayOrder = person.displayOrder
		isOnWidget = person.isOnWidget
		celebratesBirthdays = person.celebratesBirthdays
		appPicId = person.appPicId
		widgetPicId = person.widgetPicId
		originalPicId = person.originalPicId
		appPicCrop = person.appPicCrop
		widgetPicCrop = person.widgetPicCrop
	}

	/// The person with only the pictures in `stored`, the others gone. A framing that refers to a missing original goes
	/// with it, as for a picture picked before originals were kept.
	public func keepingPictures(_ stored: Set<UUID>) -> BackupPerson {
		let kept = { (id: UUID?) in id.flatMap { stored.contains($0) ? $0 : nil } }
		var person = self
		person.appPicId = kept(appPicId)
		person.widgetPicId = kept(widgetPicId)
		person.originalPicId = kept(originalPicId)
		if person.appPicId == nil || (originalPicId != nil && person.originalPicId == nil) { person.appPicCrop = nil }
		if person.widgetPicId == nil || (originalPicId != nil && person.originalPicId == nil) { person.widgetPicCrop = nil }
		return person
	}

	/// Every picture the person refers to, each once, whichever roles share it.
	public var pictureIds: [UUID] {
		var seen = Set<UUID>()
		return [appPicId, widgetPicId, originalPicId].compactMap { $0 }.filter { seen.insert($0).inserted }
	}
}
