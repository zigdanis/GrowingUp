import Foundation

/// A backup read back and checked: its document, and for each photo file it lists, a file whose bytes match.
public struct LoadedBackup: Sendable {
	public let document: BackupDocument
	/// The checked file for each `BackupPhoto.file` of the document.
	public let photoFiles: [String: URL]

	public init(document: BackupDocument, photoFiles: [String: URL]) {
		self.document = document
		self.photoFiles = photoFiles
	}
}
