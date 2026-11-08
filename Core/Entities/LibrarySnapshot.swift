import Foundation

/// The library as a backup is about to be written: its document, and where each photo file it lists lies on the
/// device now.
public struct LibrarySnapshot: Sendable {
	public let document: BackupDocument
	/// The device's file for each `BackupPhoto.file` of the document.
	public let photoSources: [String: URL]

	public init(document: BackupDocument, photoSources: [String: URL]) {
		self.document = document
		self.photoSources = photoSources
	}
}
