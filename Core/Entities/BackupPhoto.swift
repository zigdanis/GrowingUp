/// One photo file of a backup: the name the app keeps it under and the file in the backup's `photos` folder that holds
/// its bytes, named by their SHA-256, so equal photos share one file and a damaged one shows.
public struct BackupPhoto: Codable, Equatable, Hashable, Sendable {
	/// The app's file name, such as `<UUID>.heic`; see `PhotoFileName`.
	public var name: String
	/// The file in `photos`, such as `<sha256>.heic`.
	public var file: String
	public var size: Int

	public init(name: String, file: String, size: Int) {
		self.name = name
		self.file = file
		self.size = size
	}
}
