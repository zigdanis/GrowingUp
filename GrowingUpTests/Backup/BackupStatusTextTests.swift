import Core
import XCTest

@testable import GrowingUp

final class BackupStatusTextTests: XCTestCase {
	private let now = Date(timeIntervalSince1970: 1_800_000_000)

	private func describe(
		isEnabled: Bool = true, availability: ICloudBackupAvailability = .available, isBackingUp: Bool = false,
		lastBackupAt: Date? = nil, uploadState: BackupUploadState? = nil, lastWriteFailed: Bool = false
	) -> String {
		BackupStatusText.describe(
			isEnabled: isEnabled, availability: availability, isBackingUp: isBackingUp, lastBackupAt: lastBackupAt,
			uploadState: uploadState, lastWriteFailed: lastWriteFailed, now: now)
	}

	func testTheSwitchAndICloudComeFirst() {
		XCTAssertTrue(describe(isEnabled: false, availability: .unavailable, lastWriteFailed: true).hasPrefix("iCloud backup is off."))
		XCTAssertEqual(describe(availability: .checking), "Checking iCloud…")
		XCTAssertTrue(describe(availability: .unavailable, lastWriteFailed: true).hasPrefix("iCloud is not available."))
	}

	func testAFailureOutranksProgress() {
		XCTAssertEqual(
			describe(isBackingUp: true, uploadState: .failed, lastWriteFailed: true),
			"Couldn't save the backup. Check that this device has free space.")
		XCTAssertEqual(
			describe(isBackingUp: true, lastBackupAt: now, uploadState: .failed),
			"Couldn't upload the backup. Check that your iCloud storage is not full.")
		XCTAssertEqual(describe(isBackingUp: true, lastBackupAt: now), "Backing up…")
	}

	func testTheLastBackupSaysWhenAndWhetherICloudHasIt() {
		XCTAssertEqual(describe(), "Your people and photos are backed up to iCloud after each change.")
		let earlier = now.addingTimeInterval(-120)
		let last = describe(lastBackupAt: earlier, uploadState: .uploaded)
		XCTAssertTrue(last.hasPrefix("Last backup "), last)
		XCTAssertTrue(last.contains("2"), last)
		XCTAssertFalse(last.contains("Uploading"), last)
		XCTAssertTrue(describe(lastBackupAt: earlier, uploadState: .uploading).hasSuffix("Uploading to iCloud…"))
	}
}
