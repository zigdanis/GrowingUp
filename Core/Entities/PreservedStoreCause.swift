import CoreData
import Foundation

/// Why store recovery set a library aside, as a category that may leave the device: no path, record or name.
public enum PreservedStoreCause: Hashable, Sendable {
	/// Core Data reported this model incompatibility, an `NSCocoaErrorDomain` code that `PersistentStoreRecovery` accepts.
	case incompatibleModel(code: Int)
	/// A recovery was interrupted and completed by a later launch, which no longer knew the original error.
	case interrupted
	/// Set aside by a version of the app that noted no cause.
	case unknown

	/// The error a crash report groups this cause under.
	public var reportedError: NSError {
		switch self {
		case .incompatibleModel(let code): NSError(domain: NSCocoaErrorDomain, code: code)
		case .interrupted: NSError(domain: Self.domain, code: 1)
		case .unknown: NSError(domain: Self.domain, code: 0)
		}
	}

	static let domain = "pro.ziganshin.GrowingUp.PreservedStore"
}
