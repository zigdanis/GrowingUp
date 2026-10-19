import CoreData
import XCTest

@testable import Core

final class PersistentStoreRecoveryTests: XCTestCase {
	func testOnlyExplicitModelIncompatibilityAllowsBackup() {
		for code in [NSPersistentStoreIncompatibleVersionHashError, NSMigrationMissingSourceModelError] {
			XCTAssertTrue(PersistentStoreRecovery.shouldBackUp(NSError(domain: NSCocoaErrorDomain, code: code)))
			XCTAssertFalse(PersistentStoreRecovery.shouldBackUp(NSError(domain: NSPOSIXErrorDomain, code: code)))
		}
	}

	func testPermissionProtectionIOAndGenericMigrationErrorsLeaveStoreAlone() {
		let incompatible = NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreIncompatibleVersionHashError)
		for code in [NSFileReadNoPermissionError, NSFileWriteNoPermissionError, NSFileReadUnknownError,
			NSPersistentStoreOpenError, NSMigrationError, NSPersistentStoreOperationError]
		{
			let error = NSError(domain: NSCocoaErrorDomain, code: code, userInfo: [NSUnderlyingErrorKey: incompatible])
			XCTAssertFalse(PersistentStoreRecovery.shouldBackUp(error), "Unexpected recovery for \(code)")
		}
		XCTAssertFalse(PersistentStoreRecovery.shouldBackUp(NSError(domain: NSPOSIXErrorDomain, code: 5)))
	}
}
