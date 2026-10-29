import Core
import SwiftUI
import XCTest

@testable import GrowingUp

/// The edit mode records which controls are used and reports failures it shows, but not a rule its alert explains.
@MainActor
final class PersonEditorAnalyticsTests: XCTestCase {
	func testPhotoAndBirthdayControlsAreTracked() async {
		let (mode, analytics) = makeMode(person: Person.createPerson())
		mode.show(.date)
		mode.show(.time)
		mode.placePhoto(.whole(image()), from: .camera)
		mode.placeWidgetPicture(.whole(image()))
		mode.editor.removeMainPhoto()
		XCTAssertEqual(
			analytics.events,
			[
				.birthdayPickerOpened(.date), .birthdayPickerOpened(.time), .photoPicked(source: .camera), .widgetPictureFramed,
				.photoRemoved
			])
		XCTAssertNil(mode.editor.appImage)
	}

	func testFailedSaveAndRemovalAreReported() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success([])
		var person = Person.createPerson()
		person.isOnWidget = false
		gateway.editPersonResultToBeReturned = .failure(.coreDataSaveFailed)
		gateway.removePersonResultToBeReturned = .failure(.coreDataSaveFailed)
		let (mode, analytics) = makeMode(person: person, gateway: gateway)
		await mode.editor.load()
		mode.editor.name = "Changed"
		await mode.editor.save()
		await mode.editor.remove()
		XCTAssertEqual(analytics.operations, ["save_person", "remove_person"])
		XCTAssertNotNil(mode.editor.error)
	}

	func testAReframeCountsOnlyOnceASaveLands() async {
		let person = Person.createPerson()
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success([person])
		gateway.editPersonResultToBeReturned = .failure(.coreDataSaveFailed)
		let (mode, analytics) = makeMode(person: person, gateway: gateway)
		await mode.editor.load()
		mode.updateCanvas(CGSize(width: 300, height: 600), safeAreaInsets: EdgeInsets())
		await mode.loadPhoto()
		mode.drag(by: CGSize(width: 40, height: 0))
		mode.endDrag()
		XCTAssertTrue(mode.hasReframed)
		await mode.done()
		XCTAssertFalse(analytics.events.contains(.photoReframed), "The save failed")
		XCTAssertEqual(analytics.operations, ["save_person"])
		gateway.editPersonResultToBeReturned = .success(person)
		await mode.done()
		XCTAssertEqual(analytics.events.filter { $0 == .photoReframed }.count, 1, "The retry stored the framing")
	}

	func testASeventhPinnedPersonIsNoFailure() async {
		let gateway = PersonsGatewaySpy()
		let pinned = (0..<Constants.widgetPeopleLimit).map { _ in
			var person = Person.createPerson()
			person.isOnWidget = true
			return person
		}
		gateway.fetchPersonsResultToBeReturned = .success(pinned)
		let (mode, analytics) = makeMode(person: nil, gateway: gateway)
		await mode.editor.load()
		mode.editor.name = "Ada"
		mode.editor.isOnWidget = true
		await mode.editor.save()
		XCTAssertEqual(mode.editor.error?.message, CoreError.widgetPeopleLimitReached.message)
		XCTAssertEqual(analytics.failures.count, 0)
	}

	func testAFailedWidgetCountIsReported() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .failure(.coreDataFetchFailed)
		let (mode, analytics) = makeMode(person: nil, gateway: gateway)
		await mode.editor.load()
		XCTAssertEqual(analytics.operations, ["load_widget_people"])
	}

	private func makeMode(
		person: Person?, gateway: PersonsGatewaySpy = PersonsGatewaySpy()
	) -> (PersonEditModePresenter, AnalyticsGatewaySpy) {
		let analytics = AnalyticsGatewaySpy()
		let load: (PersonImage) async throws -> UIImage = { _ in self.image() }
		let configurator = SceneConfigurator(gateway: gateway, loadImage: load, loadOriginal: load, analytics: analytics)
		let editor = configurator.editor(person: person, onMutation: { _ in })
		return (PersonEditModePresenter(editor: editor, now: Date.init, onCancel: {}), analytics)
	}

	private func image() -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let size = CGSize(width: 90, height: 120)
		return UIGraphicsImageRenderer(size: size, format: format).image { context in
			UIColor.orange.setFill()
			context.fill(CGRect(origin: .zero, size: size))
		}
	}
}
