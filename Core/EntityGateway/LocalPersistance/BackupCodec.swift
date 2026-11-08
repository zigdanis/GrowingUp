import CryptoKit
import Foundation

/// Writes and reads `backup.json`, the `BackupDocument` of a backup, and checks what it names before anything uses it:
/// a backup can come from a file the person picked, so nothing in it is trusted.
public enum BackupCodec {
	/// Far beyond any real library of `Constants.peopleLimit` people; anything larger is not a backup.
	public static let maximumDocumentSize = 4 << 20
	private static let maximumPeople = 1000
	private static let photoExtensions: Set<String> = ["png", "jpg", "heic"]

	public static func encode(_ document: BackupDocument) throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		encoder.dateEncodingStrategy = .custom { date, encoder in
			var container = encoder.singleValueContainer()
			try container.encode(date.formatted(Self.dateFormat))
		}
		return try encoder.encode(document)
	}

	/// A SHA-256 of what `document` holds, without when, by which version or on which device it was written: two backups
	/// of the same library share it, so an unchanged library needs no new backup. Photos count by their files' digests.
	public static func contentHash(of document: BackupDocument) throws -> String {
		var content = document
		content.createdAt = .distantPast
		content.appVersion = ""
		content.deviceModel = ""
		return SHA256.hash(data: try encode(content)).map { String(format: "%02x", $0) }.joined()
	}

	/// The document in `data`, once it is a GrowingUp backup in a format this version reads and every name in it is
	/// one the app could have written.
	public static func decode(_ data: Data) throws -> BackupDocument {
		guard data.count <= maximumDocumentSize else { throw BackupError.notABackup }
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .custom { decoder in
			let container = try decoder.singleValueContainer()
			let text = try container.decode(String.self)
			if let date = try? Date(text, strategy: Self.dateFormat) { return date }
			if let date = try? Date(text, strategy: .iso8601) { return date }
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO 8601 date")
		}
		// The fields that tell whether the rest can be read at all.
		let header = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
		guard header?["format"] as? String == BackupDocument.formatName, let version = header?["formatVersion"] as? Int else {
			throw BackupError.notABackup
		}
		guard version <= BackupDocument.currentFormatVersion else { throw BackupError.newerVersion }
		let document: BackupDocument
		do {
			document = try decoder.decode(BackupDocument.self, from: data)
		} catch {
			throw BackupError.notABackup
		}
		try validate(document)
		return document
	}

	/// The name of the file in a backup's `photos` folder that holds a photo stored under `name`, with `digest` as its
	/// SHA-256: the digest, with the photo's own extension so the file still opens as an image.
	static func photoFile(digest: String, name: String) -> String {
		digest + "." + URL(fileURLWithPath: name).pathExtension.lowercased()
	}

	/// Whether `file` is a name `photoFile(digest:name:)` gives.
	public static func isPhotoFile(_ file: String) -> Bool {
		let url = URL(fileURLWithPath: file)
		let digest = url.deletingPathExtension().lastPathComponent
		return photoExtensions.contains(url.pathExtension) && digest.count == 64
			&& digest.allSatisfy { $0.isHexDigit && !$0.isUppercase } && url.lastPathComponent == file
	}

	/// The SHA-256 a photo file's name records.
	static func digest(inPhotoFile file: String) -> String {
		URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
	}

	private static func validate(_ document: BackupDocument) throws {
		guard document.people.count <= maximumPeople, Set(document.people.map(\.id)).count == document.people.count else {
			throw BackupError.notABackup
		}
		var names = Set<String>()
		for photo in document.photos {
			guard PhotoFileName.isPhoto(photo.name), !photo.name.contains("/"), isPhotoFile(photo.file), photo.size >= 0,
				URL(fileURLWithPath: photo.name).pathExtension.lowercased() == URL(fileURLWithPath: photo.file).pathExtension,
				names.insert(photo.name.lowercased()).inserted
			else { throw BackupError.notABackup }
		}
		let pictures = Set(document.photos.compactMap { PhotoFileName.id(of: $0.name) })
		for person in document.people {
			// Every picture a person refers to has its file: a restore must never quietly lose a photo.
			guard person.pictureIds.allSatisfy(pictures.contains) else { throw BackupError.notABackup }
			let crops = [person.appPicCrop, person.widgetPicCrop].compactMap { $0 }
			guard crops.allSatisfy({ PhotoCrop(storedValue: $0.storedValue) != nil }) else { throw BackupError.notABackup }
		}
	}

	/// ISO 8601 to the millisecond, so a person's creation date, which orders people never reordered, comes back as it was.
	private static let dateFormat = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
}
