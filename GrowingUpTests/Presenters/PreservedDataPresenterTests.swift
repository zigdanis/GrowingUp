import Core
import XCTest

@testable import GrowingUp

@MainActor
final class PreservedDataPresenterTests: XCTestCase {
	func testNothingPreservedShowsNothingAndReportsNothing() async {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh(people: [])
		XCTAssertNil(presenter.newest)
		XCTAssertEqual(analytics.failures.count, 0)
		let withoutGateway = PreservedDataPresenter(gateway: nil, analytics: analytics)
		await withoutGateway.refresh(people: [])
		XCTAssertEqual(withoutGateway.stores, [])
	}

	func testRecoveryIsShownKeepsItsPhotosAndIsReportedOnlyOnceAcrossRefreshes() async throws {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		let person = Person.createPerson()
		await presenter.refresh(people: [person])
		let active = Set([person.appPicId, person.widgetPicId].compactMap { $0 })
		XCTAssertEqual(presenter.newest?.id, "A")
		XCTAssertEqual(presenter.newest?.hasPreservedPhotos, true)
		XCTAssertEqual(analytics.operations, ["recover_store"])
		let reported = try XCTUnwrap(analytics.failures.first).sanitizedError
		XCTAssertEqual(reported.domain, NSCocoaErrorDomain)
		XCTAssertEqual(reported.code, 134_100)
		XCTAssertEqual(reported.localizedDescription, "\(NSCocoaErrorDomain) 134100 (NSError)", "Only the category leaves the device")
		await presenter.refresh(people: [person])
		XCTAssertEqual(analytics.operations, ["recover_store"])
		XCTAssertEqual(
			gateway.calls, [.stores, .preservePhotos("A", active), .markReported("A"), .stores], "Photos are kept once, the recovery reported once")
	}

	func testPhotosWaitUntilThePeopleLoadButTheRecoveryShowsAtOnce() async {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh(people: nil)
		XCTAssertEqual(presenter.newest?.hasPreservedPhotos, false)
		XCTAssertEqual(gateway.calls, [.stores, .markReported("A")])
		await presenter.refresh(people: [])
		XCTAssertEqual(presenter.newest?.hasPreservedPhotos, true)
		await presenter.refresh(people: [])
		XCTAssertEqual(gateway.calls.filter { if case .preservePhotos = $0 { true } else { false } }, [.preservePhotos("A", [])])
	}

	func testFailuresAreReportedAndTheStoreStillShows() async {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A", cause: .unknown)])
		gateway.fail(["preservePhotos"])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh(people: [])
		XCTAssertEqual(presenter.newest?.id, "A")
		XCTAssertEqual(analytics.operations, ["preserve_photos", "recover_store"])
		gateway.fail(["stores"])
		await presenter.refresh(people: [])
		XCTAssertEqual(analytics.operations.last, "read_preserved_data")
		XCTAssertEqual(presenter.stores, [])
		gateway.fail([])
		await presenter.refresh(people: [])
		XCTAssertEqual(presenter.newest?.hasPreservedPhotos, true, "A later refresh keeps the photos after all")
	}

	func testExportPreparesAnArchiveForTheShareSheetAndCleansUpAfter() async throws {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		let person = Person.createPerson()
		await presenter.refresh(people: [person])
		let store = try XCTUnwrap(presenter.newest)
		await presenter.startExport(store, people: [person])
		XCTAssertEqual(presenter.export, .ready(URL(fileURLWithPath: "/tmp/A.zip")))
		XCTAssertEqual(analytics.events, [.preservedDataExported])
		presenter.finishExport()
		XCTAssertEqual(presenter.export, .idle)
		XCTAssertEqual(gateway.calls.suffix(3).first, .removeExports)
		XCTAssertEqual(gateway.calls.last, .removeExports)
	}

	func testFailedExportCanBeRetried() async throws {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh(people: [])
		let store = try XCTUnwrap(presenter.newest)
		gateway.fail(["export"])
		await presenter.startExport(store, people: [])
		XCTAssertEqual(presenter.export, .idle)
		XCTAssertEqual(presenter.failure, .export)
		XCTAssertEqual(analytics.operations.last, "export_preserved_data")
		XCTAssertEqual(analytics.events, [])
		gateway.fail([])
		await presenter.startExport(store, people: [])
		XCTAssertEqual(presenter.export, .ready(URL(fileURLWithPath: "/tmp/A.zip")))
	}

	func testConfirmedDeletionRemovesTheStoreAndKeepsTheActivePhotos() async throws {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A"), PreservedStoreGatewaySpy.store("B")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		let person = Person.createPerson()
		await presenter.refresh(people: [person])
		await presenter.delete(try XCTUnwrap(presenter.newest), people: [person])
		XCTAssertEqual(presenter.stores.map(\.id), ["B"])
		XCTAssertEqual(gateway.calls.last, .delete("A", PreservedDataPresenter.photoIDs(of: [person])))
		XCTAssertFalse(presenter.isDeleting)
	}

	func testFailedDeletionKeepsTheStoreAndExplainsIt() async throws {
		let analytics = AnalyticsGatewaySpy()
		let gateway = PreservedStoreGatewaySpy(stores: [PreservedStoreGatewaySpy.store("A")])
		let presenter = PreservedDataPresenter(gateway: gateway, analytics: analytics)
		await presenter.refresh(people: nil)
		gateway.fail(["delete"])
		await presenter.delete(try XCTUnwrap(presenter.newest), people: nil)
		XCTAssertEqual(presenter.stores.map(\.id), ["A"])
		XCTAssertEqual(presenter.failure, .delete)
		XCTAssertEqual(analytics.operations.last, "delete_preserved_data")
		XCTAssertEqual(gateway.calls.last, .delete("A", nil), "Before the people load, the loose photos all stay")
	}
}
