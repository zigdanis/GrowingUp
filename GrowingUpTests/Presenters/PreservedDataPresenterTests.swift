import Core
import XCTest

@testable import GrowingUp

@MainActor
final class PreservedDataPresenterTests: XCTestCase {
	func testNothingPreservedShowsNothingAndReportsNothing() async {
		let analytics = AnalyticsGatewaySpy()
		let presenter = PreservedDataPresenter(gateway: PreservedStoreGatewaySpy(stores: []), analytics: analytics)
		await presenter.refresh()
		XCTAssertNil(presenter.newest)
		XCTAssertEqual(analytics.failures.count, 0)
		let withoutGateway = PreservedDataPresenter(gateway: nil, analytics: analytics)
		await withoutGateway.refresh()
		XCTAssertEqual(withoutGateway.stores, [])
	}

	func testRecoveryIsShownKeepsItsPhotosAndIsReportedOnlyOnceAcrossRefreshes() async throws {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh()
		XCTAssertEqual(presenter.newest?.id, "A")
		XCTAssertEqual(presenter.newest?.hasPreservedPhotos, true)
		XCTAssertEqual(analytics.operations, ["recover_store"])
		let reported = try XCTUnwrap(analytics.failures.first).sanitizedError
		XCTAssertEqual(reported.domain, NSCocoaErrorDomain)
		XCTAssertEqual(reported.code, 134_100)
		XCTAssertEqual(reported.localizedDescription, "\(NSCocoaErrorDomain) 134100 (NSError)", "Only the category leaves the device")
		// A relaunch, or a return to the foreground, reads the same store again.
		await presenter.refresh()
		XCTAssertEqual(analytics.operations, ["recover_store"])
		XCTAssertEqual(gateway.calls, [.stores, .preservePhotos("A"), .markReported("A"), .stores], "Photos are kept once, the recovery reported once")
	}

	func testConcurrentRefreshesReportARecoveryOnce() async {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		async let first: Void = presenter.refresh()
		async let second: Void = presenter.refresh()
		_ = await (first, second)
		XCTAssertEqual(analytics.operations, ["recover_store"])
	}

	func testFailuresAreReportedAndTheStoreStillShows() async {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A", cause: .unknown)])
		gateway.fail(["preservePhotos"])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh()
		XCTAssertEqual(presenter.newest?.id, "A")
		XCTAssertEqual(analytics.operations, ["preserve_photos", "recover_store"])
		XCTAssertEqual(analytics.failures.last?.sanitizedError.domain, PreservedStoreCause.unknown.reportedError.domain)
		gateway.fail(["stores"])
		await presenter.refresh()
		XCTAssertEqual(analytics.operations.last, "read_preserved_data")
		XCTAssertEqual(presenter.stores.map(\.id), ["A"], "A failed read keeps the notice")
		gateway.fail([])
		await presenter.refresh()
		XCTAssertEqual(presenter.newest?.hasPreservedPhotos, true, "A later refresh keeps the photos after all")
	}

	func testExportPreparesAnArchiveForTheShareSheetAndCleansUpAfter() async throws {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh()
		await presenter.startExport(try XCTUnwrap(presenter.newest))
		XCTAssertEqual(presenter.export, .ready(URL(fileURLWithPath: "/tmp/A.zip")))
		XCTAssertEqual(analytics.events, [.preservedDataExported])
		presenter.finishExport()
		XCTAssertEqual(presenter.export, .idle)
		XCTAssertEqual(Array(gateway.calls.suffix(3)), [.removeExports, .export("A"), .removeExports])
	}

	func testFailedExportIsExplainedAndCanBeRetried() async throws {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh()
		let store = try XCTUnwrap(presenter.newest)
		gateway.fail(["export"])
		await presenter.startExport(store)
		XCTAssertEqual(presenter.export, .idle)
		XCTAssertEqual(presenter.failure, .export)
		XCTAssertEqual(analytics.operations.last, "export_preserved_data")
		XCTAssertEqual(analytics.events, [])
		XCTAssertEqual(presenter.stores, [store], "The preserved store stays")
		gateway.fail([])
		presenter.failure = nil
		await presenter.startExport(store)
		XCTAssertEqual(presenter.export, .ready(URL(fileURLWithPath: "/tmp/A.zip")))
	}

	func testConfirmedDeletionRemovesOnlyThatStore() async throws {
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A"), PreservedStoreGatewaySpy.store("B")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: AnalyticsGatewaySpy())
		await presenter.refresh()
		await presenter.delete(try XCTUnwrap(presenter.newest))
		XCTAssertEqual(presenter.stores.map(\.id), ["B"])
		XCTAssertEqual(gateway.calls.last, .delete("A"))
		XCTAssertFalse(presenter.isDeleting)
	}

	func testFailedDeletionKeepsTheStoreAndExplainsIt() async throws {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh()
		gateway.fail(["delete"])
		await presenter.delete(try XCTUnwrap(presenter.newest))
		XCTAssertEqual(presenter.stores.map(\.id), ["A"])
		XCTAssertEqual(presenter.failure, .delete)
		XCTAssertEqual(analytics.operations.last, "delete_preserved_data")
	}

	func testAnExportTheClosedSheetAbandonedCleansUpWithoutOpeningTheShareSheet() async throws {
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: AnalyticsGatewaySpy())
		await presenter.refresh()
		let store = try XCTUnwrap(presenter.newest)
		let gate = DispatchSemaphore(value: 0)
		gateway.exportGate = gate
		let export = Task { await presenter.startExport(store) }
		while presenter.export != .preparing { await Task.yield() }
		presenter.abandonExport()
		XCTAssertEqual(presenter.export, .preparing, "No new export starts into the folder cleanup empties")
		gate.signal()
		await export.value
		XCTAssertEqual(presenter.export, .idle)
		XCTAssertEqual(gateway.calls.last, .removeExports)
		// A finished archive the sheet no longer shows goes at once.
		gateway.exportGate = nil
		await presenter.startExport(store)
		presenter.abandonExport()
		XCTAssertEqual(presenter.export, .idle)
		XCTAssertEqual(gateway.calls.last, .removeExports)
	}

	func testARecoveryWhoseNoteFailsToSaveIsReportedAgainLater() async {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		gateway.fail(["markReported"])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh()
		XCTAssertEqual(analytics.operations, ["recover_store"])
		gateway.fail([])
		await presenter.refresh()
		XCTAssertEqual(analytics.operations, ["recover_store", "recover_store"])
		await presenter.refresh()
		XCTAssertEqual(analytics.operations.count, 2)
	}
}
