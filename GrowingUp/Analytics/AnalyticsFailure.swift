import Core
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
}
