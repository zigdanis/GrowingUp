import XCTest

@testable import GrowingUp

final class BackupSettingsTests: XCTestCase {
	private var defaults: UserDefaults!
	private var suiteName = ""

	override func setUp() {
		suiteName = "BackupSettingsTests.\(UUID().uuidString)"
		defaults = UserDefaults(suiteName: suiteName)
	}

	override func tearDown() {
		defaults.removePersistentDomain(forName: suiteName)
	}

	func testTheBackupIsOnByDefaultAndKeepsItsFolder() {
		let settings = BackupSettings(defaults: defaults, prefix: "test.", deviceID: "device-a")
		XCTAssertTrue(settings.isEnabled)
		XCTAssertFalse(settings.isRestoreOfferDismissed)
		XCTAssertEqual(settings.writerID, settings.writerID)
		let writer = settings.writerID
		XCTAssertEqual(BackupSettings(defaults: defaults, prefix: "test.", deviceID: "device-a").writerID, writer)
		XCTAssertEqual(BackupSettings(defaults: defaults, prefix: "test.").writerID, writer, "An unknown device changes nothing")
	}

	func testAnotherDeviceStartsItsOwnFolderAndForgetsTheLastBackup() {
		let settings = BackupSettings(defaults: defaults, prefix: "test.", deviceID: "device-a")
		let writer = settings.writerID
		settings.lastContentHash = "hash"
		settings.lastBackupAt = Date()
		settings.isEnabled = false

		let moved = BackupSettings(defaults: defaults, prefix: "test.", deviceID: "device-b")

		XCTAssertNotEqual(moved.writerID, writer)
		XCTAssertNil(moved.lastContentHash)
		XCTAssertNil(moved.lastBackupAt)
		XCTAssertFalse(moved.isEnabled, "The person's choice moves with them")
	}

	func testAnotherICloudAccountForgetsTheLastBackup() {
		let settings = BackupSettings(defaults: defaults, prefix: "test.")
		XCTAssertFalse(settings.noteAccount(NSString(string: "account-a")))
		settings.lastContentHash = "hash"
		XCTAssertFalse(settings.noteAccount(NSString(string: "account-a")))
		XCTAssertEqual(settings.lastContentHash, "hash")
		XCTAssertTrue(settings.noteAccount(NSString(string: "account-b")))
		XCTAssertNil(settings.lastContentHash)
	}
}
