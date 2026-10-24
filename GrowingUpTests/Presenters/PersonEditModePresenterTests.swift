import Core
import SwiftUI
import XCTest

@testable import GrowingUp

@MainActor
final class PersonEditModePresenterTests: XCTestCase {
	private let calendar = Calendar.current
	private let phone = CGSize(width: 300, height: 600)

	func testATapEditsInPlaceAndNeverOpensTheSheet() async {
		let (presenter, _) = await viewing(count: 2)
		let people = presenter.persons
		presenter.edit(people[0])
		XCTAssertNotNil(presenter.editMode)
		XCTAssertTrue(presenter.editMode?.editor === presenter.editor, "The in-place session owns editing")
		XCTAssertNil(presenter.sheetEditor)
		presenter.add()
		XCTAssertNil(presenter.editMode, "A new person's session replaces the in-place one")
		XCTAssertNotNil(presenter.sheetEditor)
	}

	func testCancelDropsTheDraftWithoutAQuestion() async throws {
		let (presenter, gateway) = await viewing(count: 2)
		let people = presenter.persons
		presenter.edit(people[0])
		let mode = try XCTUnwrap(presenter.editMode)
		await mode.editor.load()
		mode.editor.name = "Unsaved"
		mode.show(.date)
		mode.cancel()
		XCTAssertNil(presenter.editMode)
		XCTAssertNil(presenter.editor)
		XCTAssertTrue(presenter.isViewing, "Cancel returns to the viewer, not the mosaic")
		XCTAssertEqual(presenter.persons.map(\.name), people.map(\.name))
		XCTAssertFalse(gateway.editPersonCalled)
	}

	func testDoneSavesOnceAndReturnsToTheUpdatedPerson() async throws {
		let (presenter, gateway) = await viewing(count: 2)
		let people = presenter.persons
		var edited = people[0]
		edited.name = "Edited"
		gateway.editPersonResultToBeReturned = .success(edited)
		var saves = 0
		gateway.onEdit = { saves += 1 }
		presenter.edit(people[0])
		let mode = try XCTUnwrap(presenter.editMode)
		await mode.editor.load()
		XCTAssertFalse(mode.canSave)
		mode.editor.name = "   "
		XCTAssertFalse(mode.canSave, "A blank name cannot be saved")
		mode.editor.name = "Edited"
		XCTAssertTrue(mode.canSave)
		async let first: Void = mode.done()
		async let second: Void = mode.done()
		_ = await (first, second)
		XCTAssertEqual(saves, 1)
		XCTAssertNil(presenter.editMode)
		XCTAssertTrue(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, edited.id)
		XCTAssertEqual(presenter.persons.first { $0.id == edited.id }?.name, "Edited")
	}

	func testAWidgetLimitErrorKeepsEditing() async throws {
		var people = makePeople(count: 7)
		for index in 1..<7 { people[index].isOnWidget = true }
		let (presenter, _) = await viewing(people)
		presenter.edit(people[0])
		let mode = try XCTUnwrap(presenter.editMode)
		await mode.editor.load()
		mode.editor.isOnWidget = true
		await mode.done()
		XCTAssertNotNil(mode.editor.error)
		XCTAssertTrue(presenter.editMode === mode, "The draft stays open to fix")
	}

	func testCapsulesShowTheDayAndAlwaysTheTime() async throws {
		var person = Person.createPerson()
		person.birthday = date(year: 2026, month: 4, day: 19, hour: 7, minute: 5)
		let russian = mode(for: person, locale: Locale(identifier: "ru_RU"))
		XCTAssertEqual(plain(russian.dateText), "19 апр. 2026 г.")
		XCTAssertEqual(russian.timeText, "7:05")
		let english = mode(for: person, locale: Locale(identifier: "en_US"))
		XCTAssertEqual(plain(english.dateText), "Apr 19, 2026")
		XCTAssertEqual(plain(english.timeText), "7:05 AM")
		person.birthday = date(year: 2026, month: 4, day: 19, hour: 0, minute: 0)
		let unknown = mode(for: person, locale: Locale(identifier: "ru_RU"))
		XCTAssertFalse(unknown.editor.hasBirthTime)
		XCTAssertEqual(unknown.timeText, "0:00", "Midnight stands for an unknown time")
	}

	func testTheAgeFollowsTheEditedBirthday() async {
		var person = Person.createPerson()
		let now = date(year: 2026, month: 10, day: 24, hour: 12, minute: 0)
		person.birthday = date(year: 2021, month: 7, day: 24, hour: 12, minute: 0)
		let editor = SceneConfigurator(gateway: PersonsGatewaySpy(), now: { now }).editor(person: person, onMutation: { _ in })
		let mode = PersonEditModePresenter(editor: editor, now: { now }, calendar: calendar, locale: Locale(identifier: "en_US"), onCancel: {})
		XCTAssertEqual(mode.ageText, "5 years, 3 months")
		editor.dayOfBirth = date(year: 2026, month: 10, day: 20, hour: 0, minute: 0)
		XCTAssertEqual(mode.ageText, "4 days")
	}

	func testOnlyOneCardOrTheRemovalAlertShows() {
		let mode = mode(for: Person.createPerson())
		XCTAssertNil(mode.popover)
		mode.show(.date)
		XCTAssertEqual(mode.popover, .date)
		mode.show(.time)
		XCTAssertEqual(mode.popover, .time)
		mode.dismissPopover()
		XCTAssertNil(mode.popover)
		mode.show(.date)
		mode.confirmRemoval()
		XCTAssertNil(mode.popover)
		XCTAssertTrue(mode.isConfirmingRemoval)
		mode.show(.time)
		XCTAssertFalse(mode.isConfirmingRemoval)
	}

	func testTheWidgetPictureButtonNeedsAMainPhoto() async {
		var person = Person.createPerson()
		person.appPicId = nil
		person.widgetPicId = nil
		let mode = mode(for: person)
		XCTAssertFalse(mode.showsWidgetPictureButton)
		mode.editor.setMainPhoto(image(width: 900, height: 1200))
		XCTAssertTrue(mode.showsWidgetPictureButton)
		mode.editor.removeMainPhoto()
		XCTAssertFalse(mode.showsWidgetPictureButton)
	}

	func testFramingKeepsThePhotoCoveringTheScreenWithinTheZoomLimits() async {
		let mode = mode(for: Person.createPerson(), photo: image(width: 900, height: 1200))
		await mode.loadPhoto()
		mode.updateCanvas(phone, safeAreaInsets: EdgeInsets())
		XCTAssertFalse(mode.hasReframed)
		mode.magnify(by: 0.5)
		XCTAssertTrue(mode.isFraming)
		XCTAssertGreaterThan(mode.framing.scale, 0.5, "Pinching below the cover resists")
		mode.endMagnify()
		XCTAssertEqual(mode.framing, .identity)
		XCTAssertFalse(mode.isFraming)
		mode.magnify(by: 10)
		mode.endMagnify()
		XCTAssertEqual(mode.framing.scale, CropGeometry.maxZoom)
		mode.resetFraming()
		mode.drag(by: CGSize(width: 500, height: 500))
		mode.endDrag()
		XCTAssertEqual(mode.framing.offset, CGSize(width: 75, height: 0), "The photo never uncovers the screen")
		XCTAssertTrue(mode.hasReframed)
		// A 3:4 window is wider than a main photo may be, so a 280 pt column stays covered, which leaves 10 pt of play.
		mode.updateCanvas(CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets())
		XCTAssertEqual(mode.framing.offset, CGSize(width: 10, height: 0), "A resized window settles the photo again")
	}

	func testANewFramingAloneCanBeSavedAndRendersTheVisibleRegion() async throws {
		let person = Person.createPerson()
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success([person])
		gateway.editPersonResultToBeReturned = .success(person)
		let editor = SceneConfigurator(gateway: gateway, loadImage: { _ in self.image(width: 900, height: 1200) })
			.editor(person: person, onMutation: { _ in })
		let mode = PersonEditModePresenter(editor: editor, now: Date.init, onCancel: {})
		await editor.load()
		await mode.loadPhoto()
		mode.updateCanvas(phone, safeAreaInsets: EdgeInsets())
		XCTAssertFalse(mode.canSave)
		mode.magnify(by: 2)
		mode.endMagnify()
		XCTAssertTrue(mode.canSave, "A new framing is a change")
		await mode.done()
		let saved = try XCTUnwrap(gateway.addPersonParameters.appImage?.uiImage?.cgImage)
		XCTAssertEqual(saved.width, 300)
		XCTAssertEqual(saved.height, 600)
		XCTAssertEqual(gateway.addPersonParameters.widgetImage?.id, person.widgetPicId, "A saved widget picture is left alone")
	}

	func testANewPhotoLandsInTheFrameAndItsWidgetPictureFollowsTheFraming() async throws {
		let person = Person.createPerson()
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success([person])
		gateway.editPersonResultToBeReturned = .success(person)
		let mode = mode(for: person, gateway: gateway)
		await mode.editor.load()
		mode.updateCanvas(phone, safeAreaInsets: EdgeInsets())
		mode.editor.setMainPhoto(image(width: 900, height: 1200))
		let derived = mode.editor.widgetImage?.id
		await mode.loadPhoto()
		XCTAssertEqual(mode.framing, .identity)
		mode.drag(by: CGSize(width: 40, height: 0))
		mode.endDrag()
		await mode.done()
		XCTAssertNotEqual(gateway.addPersonParameters.widgetImage?.id, derived)
		XCTAssertNotEqual(gateway.addPersonParameters.widgetImage?.id, person.widgetPicId)
	}

	func testRemovalAsksWithTheNameAndClosesTheViewer() async throws {
		let (presenter, gateway) = await viewing(count: 3)
		let people = presenter.persons
		gateway.removePersonResultToBeReturned = .success(())
		presenter.edit(people[1])
		let mode = try XCTUnwrap(presenter.editMode)
		XCTAssertTrue(mode.removalTitle.contains(people[1].name))
		mode.confirmRemoval()
		await mode.remove()
		XCTAssertFalse(mode.isConfirmingRemoval)
		XCTAssertFalse(presenter.isViewing)
		XCTAssertNil(presenter.editMode)
		XCTAssertEqual(presenter.persons.map(\.id), [people[0].id, people[2].id])
	}

	func testAWidgetLinkDuringDoneKeepsTheLinkedPersonShown() async throws {
		let (presenter, gateway) = await viewing(count: 2)
		let people = presenter.persons
		var edited = people[0]
		edited.name = "Edited"
		gateway.editPersonResultToBeReturned = .success(edited)
		presenter.edit(people[0])
		let mode = try XCTUnwrap(presenter.editMode)
		await mode.editor.load()
		mode.editor.name = "Edited"
		gateway.onEdit = {
			presenter.open(URL(string: "growingup-app://?\(Constants.widgetPersonIDKey)=\(people[1].id.uuidString)")!)
		}
		await mode.done()
		XCTAssertEqual(presenter.persons.first { $0.id == edited.id }?.name, "Edited", "The save still lands")
		XCTAssertTrue(presenter.isViewing)
		XCTAssertEqual(presenter.selectedID, people[1].id, "The linked person stays shown")
		XCTAssertNil(presenter.editMode)
	}

	func testCancelFromAReplacedSessionLeavesTheNewOneOpen() async throws {
		let (presenter, _) = await viewing(count: 2)
		let people = presenter.persons
		presenter.edit(people[0])
		let replaced = try XCTUnwrap(presenter.editMode)
		presenter.add()
		let adding = presenter.editor
		replaced.cancel()
		XCTAssertNotNil(adding)
		XCTAssertTrue(presenter.editor === adding)
		XCTAssertTrue(presenter.sheetEditor === adding)
	}

	func testClosingTheViewerDropsTheDraft() async throws {
		let (presenter, _) = await viewing(count: 2)
		let people = presenter.persons
		presenter.edit(people[0])
		XCTAssertNotNil(presenter.editMode)
		presenter.closeViewer()
		XCTAssertFalse(presenter.isViewing)
		XCTAssertNil(presenter.editor)
		XCTAssertNil(presenter.sheetEditor, "An in-place draft never reappears as the sheet")
	}
}

extension PersonEditModePresenterTests {
	/// A loaded presenter whose viewer shows the first of `count` people, who keep their mosaic order in `persons`.
	private func viewing(count: Int) async -> (PeoplePresenter, PersonsGatewaySpy) {
		await viewing(makePeople(count: count))
	}

	private func viewing(_ people: [Person]) async -> (PeoplePresenter, PersonsGatewaySpy) {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success(people)
		let presenter = PeoplePresenter(configurator: SceneConfigurator(gateway: gateway), reloadWidgets: {})
		await presenter.load()
		presenter.view(people[0].id)
		return (presenter, gateway)
	}

	private func mode(
		for person: Person, gateway: PersonsGatewaySpy = PersonsGatewaySpy(), photo: UIImage? = nil, locale: Locale = Locale(identifier: "en_US")
	) -> PersonEditModePresenter {
		let configurator = SceneConfigurator(gateway: gateway, loadImage: { _ in photo ?? self.image(width: 600, height: 800) })
		let editor = configurator.editor(person: person, onMutation: { _ in })
		return PersonEditModePresenter(editor: editor, now: Date.init, calendar: calendar, locale: locale, onCancel: {})
	}

	/// The text with the no-break spaces of formatted dates turned into plain ones.
	private func plain(_ text: String) -> String {
		text.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
	}

	private func makePeople(count: Int) -> [Person] {
		(0..<count).map { index in
			var person = Person.createPerson()
			person.name = "Person \(index)"
			person.createdDate = Date(timeIntervalSince1970: Double(index))
			return person
		}
	}

	private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
	}

	private func image(width: Int, height: Int) -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		let size = CGSize(width: width, height: height)
		return UIGraphicsImageRenderer(size: size, format: format).image { context in
			UIColor.orange.setFill()
			context.fill(CGRect(origin: .zero, size: size))
		}
	}
}
