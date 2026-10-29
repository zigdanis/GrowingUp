import Sentry
import XCTest

@testable import GrowingUp

/// Before a report leaves the device, only an exception's type, mechanism and stack stay: its reason, Swift runtime
/// messages, strings read from memory and `userInfo` can each hold a person's name.
final class CrashReportScrubbingTests: XCTestCase {
	func testACrashKeepsItsTypeAndMechanismButNoText() throws {
		let event = Event(level: .fatal)
		let exception = Exception(value: "Ada Lovelace > *** -[__NSArrayM insertObject:atIndex:]", type: "NSInvalidArgumentException")
		let mechanism = Mechanism(type: "nsexception")
		mechanism.desc = "Ada Lovelace"
		mechanism.data = ["signal": ["number": 6], "crash_info_messages": ["Fatal error: Ada Lovelace"]]
		exception.mechanism = mechanism
		event.exceptions = [exception]
		event.context = ["user info": ["name": "Ada Lovelace"], "app_state": ["people_count": 2]]

		let scrubbed = try XCTUnwrap(SentryCrashReportingGateway.scrubbed(event))
		let kept = try XCTUnwrap(scrubbed.exceptions?.first)
		XCTAssertEqual(kept.type, "NSInvalidArgumentException")
		XCTAssertNil(kept.value)
		XCTAssertEqual(kept.mechanism?.type, "nsexception")
		XCTAssertNil(kept.mechanism?.desc)
		XCTAssertEqual(kept.mechanism?.data?.keys.sorted(), ["signal"])
		XCTAssertEqual(scrubbed.context?.keys.sorted(), ["app_state"])
	}

	func testAHandledFailureKeepsItsSanitizedValue() throws {
		let event = Event(level: .error)
		event.tags = [SentryCrashReportingGateway.operationTag: "save_person"]
		event.exceptions = [Exception(value: "Code: 134050", type: "NSCocoaErrorDomain")]
		let scrubbed = try XCTUnwrap(SentryCrashReportingGateway.scrubbed(event))
		XCTAssertEqual(scrubbed.exceptions?.first?.value, "Code: 134050")
	}
}
