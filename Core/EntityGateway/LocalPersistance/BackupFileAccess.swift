import Foundation

/// How the files of a `BackupFolder` are read and written: directly, as for a folder on the device, or through
/// `NSFileCoordinator`, as iCloud asks for the files of the app's ubiquity container. A coordinated read first asks
/// iCloud to download a file that is only in the cloud, and a file not downloaded yet, which may show only as a hidden
/// `.<name>.icloud` placeholder, still counts as there.
public struct BackupFileAccess: Sendable {
	/// Plain file operations, as for an unpacked archive or a test folder.
	public static let local = BackupFileAccess(usesFileCoordination: false)
	/// Coordinated, for the app's iCloud container.
	public static let iCloud = BackupFileAccess(usesFileCoordination: true)

	public let usesFileCoordination: Bool
	/// How long a read may wait for iCloud to download a file before it fails: without a network it would wait for good.
	public let readTimeout: TimeInterval

	public init(usesFileCoordination: Bool, readTimeout: TimeInterval = 30) {
		self.usesFileCoordination = usesFileCoordination
		self.readTimeout = readTimeout
	}

	/// Whether there is a file at `url`, downloaded or not.
	func exists(_ url: URL) -> Bool {
		if FileManager.default.fileExists(atPath: url.path) { return true }
		return usesFileCoordination && FileManager.default.fileExists(atPath: Self.placeholder(of: url).path)
	}

	/// The size of the file at `url` when it is on the device, else nil.
	func localSize(of url: URL) -> Int? {
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		return try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
	}

	/// The names of the files in `folder`, a placeholder by the name of the file it stands for.
	func names(in folder: URL) -> [String] {
		let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
		guard usesFileCoordination else { return names }
		return Array(
			Set(
				names.map { name in
					guard name.hasPrefix("."), name.hasSuffix(".icloud"), name.count > 8 else { return name }
					return String(name.dropFirst().dropLast(7))
				}))
	}

	/// The bytes of the file at `url`, which may not be larger than `maximumSize`.
	func read(_ url: URL, maximumSize: Int) throws -> Data {
		try reading(url) { url in
			let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
			guard size <= maximumSize else { throw BackupError.notABackup }
			return try Data(contentsOf: url)
		}
	}

	/// Runs `body` with the file at `url` readable, downloaded first when it is only in iCloud.
	func reading<Value>(_ url: URL, _ body: (URL) throws -> Value) throws -> Value {
		guard usesFileCoordination else { return try body(url) }
		try? FileManager.default.startDownloadingUbiquitousItem(at: url)
		let coordinator = NSFileCoordinator(filePresenter: nil)
		let timeout = DispatchWorkItem { coordinator.cancel() }
		DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + readTimeout, execute: timeout)
		defer { timeout.cancel() }
		var coordinationError: NSError?
		var result: Result<Value, Error> = .failure(CocoaError(.fileReadUnknown))
		coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
			result = Result { try body(url) }
		}
		if let coordinationError { throw coordinationError }
		return try result.get()
	}

	/// Replaces the file at `url` with `data` in one step, so a reader never sees half of it.
	func write(_ data: Data, to url: URL) throws {
		try writing(url, options: .forReplacing) { try data.write(to: $0, options: .atomic) }
	}

	/// Replaces the file at `url` with a copy of the file at `source`.
	func copy(_ source: URL, to url: URL) throws {
		try writing(url, options: .forReplacing) { url in
			if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
			try FileManager.default.copyItem(at: source, to: url)
		}
	}

	/// Removes the file or folder at `url`, from iCloud too.
	func delete(_ url: URL) throws {
		let target = !FileManager.default.fileExists(atPath: url.path) && exists(url) ? Self.placeholder(of: url) : url
		try writing(target, options: .forDeleting) { try FileManager.default.removeItem(at: $0) }
	}

	/// Whether iCloud holds the file at `url` yet.
	func uploadState(of url: URL) -> BackupUploadState {
		let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .ubiquitousItemIsUploadedKey, .ubiquitousItemUploadingErrorKey]
		guard let values = try? url.resourceValues(forKeys: keys), values.isUbiquitousItem == true else { return .notInICloud }
		if values.ubiquitousItemUploadingError != nil { return .failed }
		return values.ubiquitousItemIsUploaded == true ? .uploaded : .uploading
	}

	private func writing(_ url: URL, options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> Void) throws {
		guard usesFileCoordination else { return try body(url) }
		var coordinationError: NSError?
		var result: Result<Void, Error> = .success(())
		NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: options, error: &coordinationError) { url in
			result = Result { try body(url) }
		}
		if let coordinationError { throw coordinationError }
		try result.get()
	}

	/// The hidden file that stands for one iCloud has not downloaded yet.
	private static func placeholder(of url: URL) -> URL {
		url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
	}
}
