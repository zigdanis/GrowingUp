import Foundation

/// The note a preserved store's folder keeps beside the SQLite files: why and when it was set aside, and what the app
/// has done with it since. Store recovery writes it before it moves the first file; folders set aside by earlier
/// versions of the app have none until the app first keeps their photos.
struct PreservedStoreManifest: Codable, Equatable {
	static let fileName = "Preserved.json"

	var formatVersion = 1
	var preservedAt: Date
	/// `incompatible_model`, `interrupted` or `unknown`; see `PreservedStoreCause`.
	var cause: String
	/// The Core Data error code of an incompatible model.
	var errorCode: Int?
	/// The version of the app that set the store aside.
	var appVersion: String?
	/// `app` or `widget`: the process whose load found the store incompatible.
	var process: String?
	/// When the photo files the store refers to were kept with it, in its `Photos` folder.
	var photosPreservedAt: Date?
	var photoFileNames: [String]?
	/// When the app reported the recovery, so each one is reported once.
	var reportedAt: Date?

	init(preservedAt: Date, cause: PreservedStoreCause, appVersion: String? = Self.currentAppVersion, process: String? = Self.currentProcess) {
		self.preservedAt = preservedAt
		self.appVersion = appVersion
		self.process = process
		switch cause {
		case .incompatibleModel(let code):
			self.cause = "incompatible_model"
			errorCode = code
		case .interrupted:
			self.cause = "interrupted"
		case .unknown:
			self.cause = "unknown"
		}
	}

	var preservedCause: PreservedStoreCause {
		switch cause {
		case "incompatible_model": errorCode.map { .incompatibleModel(code: $0) } ?? .unknown
		case "interrupted": .interrupted
		default: .unknown
		}
	}

	static func read(in folder: URL) throws -> PreservedStoreManifest? {
		let url = folder.appendingPathComponent(fileName)
		let data: Data
		do {
			data = try Data(contentsOf: url)
		} catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
			return nil
		}
		return try decoder.decode(Self.self, from: data)
	}

	/// Saves the note. A note already there that can't be read is never overwritten: it is renamed aside first, so its
	/// bytes, which may hold the original cause, stay for whoever examines the folder.
	func write(in folder: URL) throws {
		let url = folder.appendingPathComponent(Self.fileName)
		if FileManager.default.fileExists(atPath: url.path), (try? Self.read(in: folder)) == nil {
			let stamp = Int(Date().timeIntervalSince1970)
			try FileManager.default.moveItem(at: url, to: folder.appendingPathComponent("Preserved-unreadable-\(stamp)-\(UUID().uuidString).json"))
		}
		try Self.encoder.encode(self).write(to: url, options: .atomic)
	}

	static var currentAppVersion: String? {
		let info = Bundle.main.infoDictionary
		guard let version = info?["CFBundleShortVersionString"] as? String else { return nil }
		guard let build = info?["CFBundleVersion"] as? String else { return version }
		return "\(version) (\(build))"
	}

	/// An app extension's bundle has the `appex` extension; the app's does not.
	static var currentProcess: String {
		Bundle.main.bundleURL.pathExtension == "appex" ? "widget" : "app"
	}

	static let encoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		return encoder
	}()

	private static let decoder: JSONDecoder = {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return decoder
	}()
}
