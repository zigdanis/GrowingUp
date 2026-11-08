import Core
import CoreData
import Foundation

/// A handled problem worth a crash-reporting ticket: what the app was doing and what went wrong.
struct AnalyticsFailure {
	/// snake_case name of the operation, for example `save_person`.
	let operation: String
	let error: Error

	/// The error as it may leave the device. A Core Data or Foundation error can carry the failing record in its
	/// `userInfo`, and a `CoreError` message can quote one, with a person's name; only the domain, code and Swift type
	/// travel, which are what group and explain the failure. A `CoreError` gives the domain and code of the error it
	/// wraps, so different causes stay apart.
	var sanitizedError: NSError {
		let nsError = error as NSError
		let coreError = error as? CoreError
		let domain = coreError?.underlyingDomain ?? nsError.domain
		let code = coreError?.underlyingCode ?? nsError.code
		return NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: "\(domain) \(code) (\(type(of: error)))"])
	}

	/// The errors underneath, nearest first, each as `domain code`. Why a Core Data load or migration failed is usually only
	/// in its underlying SQLite, file or validation error; like `sanitizedError`, only domains and codes travel.
	var causes: [String] {
		var causes: [String] = []
		var pending = Self.causes(of: error as NSError)
		while !pending.isEmpty, causes.count < Self.maximumCauses {
			let next = pending.removeFirst()
			causes.append("\(next.domain) \(next.code)")
			pending += Self.causes(of: next)
		}
		return causes
	}

	private static let maximumCauses = 6

	/// What `error` names as its causes: its underlying errors, the several errors a validation failure groups, and the
	/// SQLite result code Core Data attaches.
	private static func causes(of error: NSError) -> [NSError] {
		var causes = error.underlyingErrors.map { $0 as NSError } + (error.userInfo[NSDetailedErrorsKey] as? [NSError] ?? [])
		if let sqliteCode = error.userInfo[NSSQLiteErrorDomain] as? Int {
			causes.append(NSError(domain: NSSQLiteErrorDomain, code: sqliteCode))
		}
		return causes
	}
}
