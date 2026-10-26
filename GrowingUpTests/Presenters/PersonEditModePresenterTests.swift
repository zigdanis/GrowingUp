import Core
import SwiftUI
import XCTest

@testable import GrowingUp

@MainActor
final class PersonEditModePresenterTests: XCTestCase {
	private let calendar = Calendar.current
	private let phone = CGSize(width: 300, height: 600)

	func testATapEditsInPlaceAndANewPersonReplacesIt() async throws {
		let (presenter, _) = await viewing(count: 2)
		let people = presenter.persons
		presenter.edit(people[0])
		let editing = try XCTUnwrap(presenter.editMode)
		XCTAssertTrue(editing.editor === presenter.editor, "The in-place session owns editing")
		XCTAssertFalse(editing.isNewPerson)
		XCTAssertTrue(editing.showsRemoveButton)
		presenter.add()
		let adding = try XCTUnwrap(presenter.editMode, "A new person's session replaces the in-place one")
		XCTAssertFalse(adding === editing)
		XCTAssertTrue(adding.isNewPerson)
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
		mode.editor.setMainPhoto(.whole(image(width: 900, height: 1200)))
		XCTAssertTrue(mode.showsWidgetPictureButton)
		mode.editor.removeMainPhoto()
		XCTAssertFalse(mode.showsWidgetPictureButton)
	}

	func testANewPhotoLandsInTheFrameAndItsWidgetPictureFollowsTheFraming() async throws {
		let person = Person.createPerson()
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success([person])
		gateway.editPersonResultToBeReturned = .success(person)
		let mode = mode(for: person, gateway: gateway)
		await mode.editor.load()
		mode.updateCanvas(phone, safeAreaInsets: EdgeInsets())
		mode.editor.setMainPhoto(.whole(image(width: 900, height: 1200)))
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
		presenter.coverDidClose()
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
		XCTAssertTrue(presenter.editMode?.editor === adding)
		XCTAssertTrue(presenter.isViewing)
	}

	func testClosingTheViewerDropsTheDraft() async throws {
		let (presenter, _) = await viewing(count: 2)
		let people = presenter.persons
		presenter.edit(people[0])
		XCTAssertNotNil(presenter.editMode)
		presenter.closeViewer()
		XCTAssertFalse(presenter.isViewing)
		XCTAssertNil(presenter.editor)
		XCTAssertNil(presenter.editMode)
	}
}

/// Framing the main photo in place and the region Done saves from it.
extension PersonEditModePresenterTests {
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
		// A 300 × 400 window is just covered by the 3:4 photo, which leaves no play.
		mode.updateCanvas(CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets())
		XCTAssertEqual(mode.framing.offset, .zero, "A resized window settles the photo again")
	}

	func testReloadingTheSamePhotoKeepsItsFraming() async {
		let mode = mode(for: Person.createPerson(), photo: image(width: 900, height: 1200))
		await mode.loadPhoto()
		mode.updateCanvas(phone, safeAreaInsets: EdgeInsets())
		mode.magnify(by: 2)
		mode.endMagnify()
		mode.drag(by: CGSize(width: 60, height: -40))
		mode.endDrag()
		let framed = mode.framing
		// Returning from the widget picture's crop restarts the screen's photo task for the same photo.
		await mode.loadPhoto()
		XCTAssertEqual(mode.framing, framed)
		XCTAssertTrue(mode.hasReframed)
		mode.editor.setMainPhoto(.whole(image(width: 900, height: 1200)))
		await mode.loadPhoto()
		XCTAssertEqual(mode.framing, .identity, "A new photo starts as the viewer would show it")
		mode.magnify(by: 2)
		mode.endMagnify()
		mode.editor.removeMainPhoto()
		await mode.loadPhoto()
		XCTAssertNil(mode.photo)
		XCTAssertEqual(mode.framing, .identity)
	}

	func testAWideWindowKeepsTheWholeWindowCovered() async throws {
		let mode = mode(for: Person.createPerson(), photo: image(width: 900, height: 1200))
		await mode.loadPhoto()
		let window = CGSize(width: 1000, height: 700)
		mode.updateCanvas(window, safeAreaInsets: EdgeInsets())
		let geometry = try XCTUnwrap(mode.photo.flatMap(mode.geometry(of:)))
		XCTAssertEqual(geometry.frameRect.width, 490, accuracy: 0.001, "Only the centred portrait column is saved")
		XCTAssertEqual(geometry.displaySize.width, 1000, accuracy: 0.001)
		XCTAssertEqual(geometry.displaySize.height, 1333.333, accuracy: 0.001)
		let columnOnly = CropGeometry(pixelSize: geometry.pixelSize, shape: .rectangle, container: window, insets: EdgeInsets())
		XCTAssertEqual(columnOnly.minScale, 0.525, accuracy: 0.001, "Covering just the column would leave 475 pt black")
		XCTAssertEqual(geometry.minScale, 1)
		mode.magnify(by: 0.5)
		mode.endMagnify()
		XCTAssertEqual(mode.framing.scale, 1, "The photo never shrinks inside the window")
		mode.drag(by: CGSize(width: 400, height: 900))
		mode.endDrag()
		XCTAssertEqual(mode.framing.offset.width, 0, accuracy: 0.001)
		XCTAssertEqual(mode.framing.offset.height, 316.667, accuracy: 0.001)
	}

	func testDoneSavesTheVisibleRegionOfTheFraming() async throws {
		let person = Person.createPerson()
		let gateway = savingGateway(for: person)
		let mode = mode(for: person, gateway: gateway, photo: quadrants())
		await mode.editor.load()
		await mode.loadPhoto()
		mode.updateCanvas(phone, safeAreaInsets: EdgeInsets())
		XCTAssertFalse(mode.canSave)
		mode.magnify(by: 2)
		mode.endMagnify()
		mode.drag(by: CGSize(width: 75, height: 150))
		mode.endDrag()
		XCTAssertTrue(mode.canSave, "A new framing is a change")
		await mode.done()
		// At 2× on a 300 × 600 pt screen, moved right and down, the screen shows source pixels x 225–525, y 150–750, so
		// the quadrants meet at column 225, row 450 of the saved photo.
		let saved = try XCTUnwrap(gateway.addPersonParameters.appImage?.uiImage)
		try assertSize(saved, width: 300, height: 600)
		try assertQuadrants(of: saved, meetingAt: CGPoint(x: 225, y: 450))
		XCTAssertEqual(gateway.addPersonParameters.widgetImage?.id, person.widgetPicId, "A saved widget picture is left alone")
	}

	func testAWideWindowSavesItsCentredColumn() async throws {
		let person = Person.createPerson()
		let gateway = savingGateway(for: person)
		let mode = mode(for: person, gateway: gateway, photo: quadrants())
		await mode.editor.load()
		await mode.loadPhoto()
		mode.updateCanvas(CGSize(width: 1000, height: 700), safeAreaInsets: EdgeInsets())
		mode.drag(by: CGSize(width: 0, height: -90))
		mode.endDrag()
		await mode.done()
		// The 490 × 700 pt column at 10/9 pt per pixel, with the photo moved up 90 pt, holds source pixels x 229–671, y 366–996,
		// so the quadrants meet at column 221, row 234 of the saved photo.
		let saved = try XCTUnwrap(gateway.addPersonParameters.appImage?.uiImage)
		try assertSize(saved, width: 442, height: 630, accuracy: 1)
		try assertQuadrants(of: saved, meetingAt: CGPoint(x: 221, y: 234))
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
		let load: (PersonImage) async throws -> UIImage = { _ in photo ?? self.image(width: 600, height: 800) }
		let configurator = SceneConfigurator(gateway: gateway, loadImage: load, loadOriginal: load)
		let editor = configurator.editor(person: person, onMutation: { _ in })
		return PersonEditModePresenter(editor: editor, now: Date.init, calendar: calendar, locale: locale, onCancel: {})
	}

	/// The text with the no-break spaces of formatted dates turned into plain ones.
	private func plain(_ text: String) -> String {
		text.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
	}

	/// A gateway that saves `person` and lists only them.
	private func savingGateway(for person: Person) -> PersonsGatewaySpy {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success([person])
		gateway.editPersonResultToBeReturned = .success(person)
		return gateway
	}

	/// A 900 × 1200 photo split into red, green, blue and yellow quadrants in reading order.
	private func quadrants() -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.opaque = true
		format.preferredRange = .standard
		let size = CGSize(width: 900, height: 1200)
		return UIGraphicsImageRenderer(size: size, format: format).image { context in
			for (index, color) in [UIColor.red, .green, .blue, .yellow].enumerated() {
				color.setFill()
				let origin = CGPoint(x: CGFloat(index % 2) * 450, y: CGFloat(index / 2) * 600)
				context.fill(CGRect(origin: origin, size: CGSize(width: 450, height: 600)))
			}
		}
	}

	private func assertSize(
		_ image: UIImage, width: Int, height: Int, accuracy: Int = 0, file: StaticString = #filePath, line: UInt = #line
	) throws {
		let pixels = try XCTUnwrap(image.cgImage, file: file, line: line)
		XCTAssertEqual(pixels.width, width, accuracy: accuracy, file: file, line: line)
		XCTAssertEqual(pixels.height, height, accuracy: accuracy, file: file, line: line)
	}

	/// Checks the four quadrant colours 20 pixels away from where the quadrants meet in `image`.
	private func assertQuadrants(of image: UIImage, meetingAt corner: CGPoint, file: StaticString = #filePath, line: UInt = #line) throws {
		let expected: [(offset: CGVector, rgb: [UInt8])] = [
			(CGVector(dx: -20, dy: -20), [255, 0, 0]), (CGVector(dx: 20, dy: -20), [0, 255, 0]),
			(CGVector(dx: -20, dy: 20), [0, 0, 255]), (CGVector(dx: 20, dy: 20), [255, 255, 0])
		]
		for item in expected {
			let column = Int(corner.x + item.offset.dx)
			let row = Int(corner.y + item.offset.dy)
			let actual = try pixel(in: image, column: column, row: row)
			let matches = zip(actual, item.rgb).allSatisfy { abs(Int($0) - Int($1)) <= 40 }
			XCTAssertTrue(matches, "Pixel at \(column), \(row) is \(actual), expected \(item.rgb)", file: file, line: line)
		}
	}

	/// Reads one sRGB pixel, addressed from the top-left corner.
	private func pixel(in image: UIImage, column: Int, row: Int) throws -> [UInt8] {
		let pixels = try XCTUnwrap(image.cgImage)
		let sRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
		let context = try XCTUnwrap(
			CGContext(
				data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: sRGB,
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
		// Core Graphics counts rows from the bottom; shift the image so the requested pixel covers the 1×1 canvas.
		context.draw(pixels, in: CGRect(x: -column, y: row + 1 - pixels.height, width: pixels.width, height: pixels.height))
		let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
		return [bytes[0], bytes[1], bytes[2]]
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
