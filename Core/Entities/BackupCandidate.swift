import Foundation

/// One backup an install of the app keeps in iCloud, as the list of backups shows it: when and on which kind of device
/// it was made and how many people it holds. An install's earlier copy is a candidate of its own.
public struct BackupCandidate: Identifiable, Equatable, Sendable {
	/// The install's folder, its UUID.
	public let folderName: String
	public let createdAt: Date
	/// `UIDevice.model`, such as `iPhone`; never the device's name.
	public let deviceModel: String
	public let peopleCount: Int
	/// Written by this install of the app.
	public let isThisDevice: Bool
	/// The copy the latest one replaced, listed when the latest is empty or can't be restored whole.
	public let isPreviousCopy: Bool

	public init(folderName: String, document: BackupDocument, isThisDevice: Bool, isPreviousCopy: Bool = false) {
		self.folderName = folderName
		createdAt = document.createdAt
		deviceModel = document.deviceModel
		peopleCount = document.people.count
		self.isThisDevice = isThisDevice
		self.isPreviousCopy = isPreviousCopy
	}

	public var id: String { isPreviousCopy ? folderName + "/previous" : folderName }
	public var isEmpty: Bool { peopleCount == 0 }
}
