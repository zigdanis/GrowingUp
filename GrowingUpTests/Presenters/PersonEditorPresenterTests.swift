import Core
import XCTest

@testable import GrowingUp

@MainActor
final class PersonEditorPresenterTests: XCTestCase {
	private let calendar = Calendar.current

	func testNewPersonBaselineIsCleanUntilANameIsEntered() async {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success([])
		let now = date(year: 2026, month: 10, day: 5, hour: 12, minute: 34)
		let presenter = SceneConfigurator(gateway: gateway, now: { now }).editor(person: nil, onMutation: { _ in })
		XCTAssertFalse(presenter.isDirty)
		await presenter.load()
		XCTAssertTrue(presenter.isOnWidget)
		XCTAssertTrue(presenter.celebratesBirthdays)
		XCTAssertFalse(presenter.hasBirthTime)
		XCTAssertEqual(presenter.birthday, calendar.startOfDay(for: now))
		XCTAssertNil(presenter.appImage)
		XCTAssertNil(presenter.widgetImage)
		XCTAssertFalse(presenter.isDirty)
		XCTAssertFalse(presenter.canSave)
		presenter.name = "Ada"
		XCTAssertTrue(presenter.canSave)
		presenter.name = "   "
		XCTAssertFalse(presenter.isDirty, "Spaces alone are no name")
		XCTAssertFalse(presenter.canSave)
		presenter.name = ""
		XCTAssertFalse(presenter.isDirty)
	}

	func testTheNameIsSavedWithoutTheSpacesAroundIt() async {
		let gateway = PersonsGatewaySpy()
		var person = Person.createPerson()
		person.name = "Ada"
		gateway.editPersonResultToBeReturned = .success(person)
		let presenter = SceneConfigurator(gateway: gateway).editor(person: person, onMutation: { _ in })
		await presenter.load()
		presenter.name = "  Ada \n"
		XCTAssertFalse(presenter.isDirty, "Spaces around the same name are no change")
		XCTAssertFalse(presenter.canSave)
		presenter.name = "  Ada Lovelace \n"
		XCTAssertTrue(presenter.canSave)
		await presenter.save()
		XCTAssertEqual(gateway.addPersonParameters.name, "Ada Lovelace")
	}

	func testExistingPersonBaselineTracksTheCelebrationChoice() async {
		var person = Person.createPerson()
		person.celebratesBirthdays = false
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		XCTAssertFalse(presenter.celebratesBirthdays)
		XCTAssertFalse(presenter.isDirty)
		presenter.celebratesBirthdays = true
		XCTAssertTrue(presenter.canSave)
		presenter.celebratesBirthdays = false
		XCTAssertFalse(presenter.isDirty)
	}

	func testCelebrationChoiceIsSaved() async {
		let gateway = PersonsGatewaySpy()
		let person = Person.createPerson()
		gateway.editPersonResultToBeReturned = .success(person)
		let presenter = SceneConfigurator(gateway: gateway).editor(person: person, onMutation: { _ in })
		await presenter.load()
		presenter.celebratesBirthdays = false
		await presenter.save()
		XCTAssertTrue(gateway.editPersonCalled)
		XCTAssertFalse(gateway.addPersonParameters.celebratesBirthdays)
	}

	func testUnknownBirthTimeIsStoredAsMidnight() async {
		var person = Person.createPerson()
		let midnight = date(year: 2020, month: 1, day: 2, hour: 0, minute: 0)
		person.birthday = midnight
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		XCTAssertFalse(presenter.hasBirthTime)
		presenter.dayOfBirth = date(year: 2021, month: 3, day: 4, hour: 9, minute: 15)
		XCTAssertEqual(presenter.birthday, date(year: 2021, month: 3, day: 4, hour: 0, minute: 0))
		presenter.dayOfBirth = midnight
		XCTAssertFalse(presenter.isDirty)
		presenter.timeOfBirth = date(year: 2024, month: 5, day: 6, hour: 14, minute: 30).addingTimeInterval(45)
		XCTAssertTrue(presenter.hasBirthTime)
		XCTAssertEqual(presenter.birthday, date(year: 2020, month: 1, day: 2, hour: 14, minute: 30))
		XCTAssertTrue(presenter.isDirty)
		presenter.timeOfBirth = midnight
		XCTAssertEqual(presenter.birthday, midnight, "Picking 00:00 stores the unknown time again")
		XCTAssertFalse(presenter.isDirty)
	}

	func testKnownBirthTimeLoadsTheToggleOn() async {
		var person = Person.createPerson()
		person.birthday = date(year: 2020, month: 1, day: 16, hour: 6, minute: 30)
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		XCTAssertTrue(presenter.hasBirthTime)
		presenter.timeOfBirth = date(year: 2020, month: 1, day: 1, hour: 0, minute: 0)
		XCTAssertTrue(presenter.hasBirthTime)
		XCTAssertEqual(presenter.birthday, date(year: 2020, month: 1, day: 16, hour: 0, minute: 0))
	}

	func testPickingAMainPhotoDerivesTheWidgetPicture() async {
		var person = Person.createPerson()
		person.appPicId = nil
		person.widgetPicId = nil
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		let photo = image(width: 900, height: 1200)
		presenter.setMainPhoto(.whole(photo))
		XCTAssertTrue(presenter.appImage?.uiImage === photo)
		XCTAssertTrue(presenter.originalImage?.uiImage === photo, "The photo is kept whole as the original")
		XCTAssertEqual(presenter.appImage?.crop, .whole)
		let widgetPixels = presenter.widgetImage?.uiImage?.cgImage
		XCTAssertEqual(widgetPixels?.width, Int(WidgetPictureDeriver.maxPixelSide))
		XCTAssertEqual(widgetPixels?.height, Int(WidgetPictureDeriver.maxPixelSide))
		XCTAssertEqual(presenter.widgetImage?.crop, PhotoCrop(minX: 0, minY: 0.125, width: 1, height: 0.75), "The centred square")
		XCTAssertNotEqual(presenter.appImage?.id, presenter.widgetImage?.id)
		XCTAssertNotEqual(presenter.originalImage?.id, presenter.appImage?.id)
		XCTAssertTrue(presenter.canSave)
	}

	func testRemovingTheMainPhotoClearsBothPictures() async {
		let person = Person.createPerson()
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		presenter.removeMainPhoto()
		XCTAssertNil(presenter.appImage)
		XCTAssertNil(presenter.widgetImage)
		XCTAssertNil(presenter.originalImage)
		XCTAssertTrue(presenter.canSave)
	}

	func testPickingThenRemovingANewPhotoRestoresTheCleanDraft() async {
		var person = Person.createPerson()
		person.appPicId = nil
		person.widgetPicId = nil
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in XCTFail("Unsaved") })
		await presenter.load()
		presenter.setMainPhoto(.whole(image(width: 900, height: 1200)))
		XCTAssertTrue(presenter.canSave)
		presenter.removeMainPhoto()
		XCTAssertFalse(presenter.isDirty)
		XCTAssertFalse(presenter.canSave)
		XCTAssertNil(presenter.appImage)
		XCTAssertNil(presenter.widgetImage)
	}

	func testReframingReplacesOnlyTheWidgetPicture() async {
		let person = Person.createPerson()
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		let reframed = image(width: 480, height: 480)
		let crop = PhotoCrop(minX: 0.1, minY: 0.2, width: 0.5, height: 0.375)
		presenter.setWidgetPhoto(FramedPhoto(source: image(width: 600, height: 800), crop: crop, picture: reframed))
		XCTAssertEqual(presenter.appImage?.id, person.appPicId)
		XCTAssertNotEqual(presenter.widgetImage?.id, person.widgetPicId)
		XCTAssertTrue(presenter.widgetImage?.uiImage === reframed)
		XCTAssertEqual(presenter.widgetImage?.crop, crop)
		XCTAssertEqual(
			presenter.originalImage?.id, person.appPicId, "A main picture saved before originals were kept now serves as the original")
		XCTAssertEqual(presenter.mainCrop, .whole, "showing all of itself")
		XCTAssertTrue(presenter.canSave)
	}

	func testMissingWidgetPictureIsNotCreatedUntilThePhotoChanges() async {
		var person = Person.createPerson()
		person.widgetPicId = nil
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		XCTAssertEqual(presenter.appImage?.id, person.appPicId)
		XCTAssertNil(presenter.widgetImage)
		XCTAssertFalse(presenter.isDirty)
	}

	func testThePhotoForFramingPrefersThePickedOriginalAndReportsLoadFailures() async {
		let stored = image(width: 600, height: 800)
		var loads: [UUID] = []
		let loader = SceneConfigurator(
			gateway: PersonsGatewaySpy(),
			loadOriginal: { image in
				loads.append(image.id)
				return stored
			})
		let person = Person.createPerson()
		let presenter = loader.editor(person: person, onMutation: { _ in })
		let loaded = await presenter.loadFramingSource()
		XCTAssertTrue(loaded === stored)
		XCTAssertEqual(loads, [person.appPicId].compactMap { $0 }, "A photo picked before originals were kept frames from its main picture")
		let picked = image(width: 900, height: 1200)
		presenter.setMainPhoto(FramedPhoto(source: picked, crop: .whole, picture: image(width: 300, height: 600)))
		let reused = await presenter.loadFramingSource()
		XCTAssertTrue(reused === picked, "A new photo frames from its whole original, not the main picture")
		XCTAssertEqual(loads.count, 1)
		var saved = Person.createPerson()
		saved.originalPicId = UUID()
		let original = loader.editor(person: saved, onMutation: { _ in })
		_ = await original.loadFramingSource()
		XCTAssertEqual(loads.last, saved.originalPicId, "A kept original is what is framed")
		let failing = SceneConfigurator(gateway: PersonsGatewaySpy(), loadOriginal: { _ in throw CoreError.missingValue })
		let failed = failing.editor(person: .createPerson(), onMutation: { _ in })
		let missing = await failed.loadFramingSource()
		XCTAssertNil(missing)
		XCTAssertEqual(failed.error?.message, CoreError.missingValue.message)
	}

	func testThePhotoLoadedForFramingIsDiscardedWhenThePhotoChangesMeanwhile() async {
		let stored = image(width: 600, height: 800)
		let started = AsyncStream.makeStream(of: Void.self)
		let gate = AsyncStream.makeStream(of: Void.self)
		let loader = SceneConfigurator(
			gateway: PersonsGatewaySpy(),
			loadOriginal: { _ in
				started.continuation.yield()
				for await _ in gate.stream { break }
				return stored
			})
		let presenter = loader.editor(person: .createPerson(), onMutation: { _ in })
		let task = Task { await presenter.loadFramingSource() != nil }
		for await _ in started.stream { break }
		presenter.setMainPhoto(.whole(image(width: 900, height: 1200)))
		gate.continuation.yield()
		let usedStaleImage = await task.value
		XCTAssertFalse(usedStaleImage)
	}

	func testOptedOutBirthdayKeepsTheIndicatorWithoutConfetti() {
		var person = Person.createPerson()
		person.birthday = date(year: 2020, month: 1, day: 16, hour: 6, minute: 0)
		person.celebratesBirthdays = false
		let birthday = date(year: 2027, month: 1, day: 16, hour: 8, minute: 0)
		let presenter = OverviewPresenter()
		presenter.tick(person: person, now: birthday, isSelected: true)
		presenter.tick(person: person, now: birthday.addingTimeInterval(60), isSelected: false)
		presenter.tick(person: person, now: birthday.addingTimeInterval(120), isSelected: true)
		XCTAssertEqual(presenter.celebrationID, 0)
		XCTAssertEqual(presenter.birthdayStatus?.isToday, true)
		person.celebratesBirthdays = true
		presenter.tick(person: person, now: birthday.addingTimeInterval(180), isSelected: true)
		XCTAssertEqual(presenter.celebrationID, 1, "Turning celebrations back on celebrates the visible birthday")
		presenter.tick(person: person, now: birthday.addingTimeInterval(240), isSelected: true)
		XCTAssertEqual(presenter.celebrationID, 1)
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

/// The main photo reframed in place, and the widget picture that may follow it.
extension PersonEditorPresenterTests {
	func testAReframedMainPhotoKeepsASavedWidgetPicture() async {
		let person = Person.createPerson()
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		let crop = PhotoCrop(minX: 0.25, minY: 0, width: 0.5, height: 1)
		presenter.reframeMainPhoto(FramedPhoto(source: image(width: 1200, height: 1200), crop: crop, picture: image(width: 600, height: 1200)))
		XCTAssertNotEqual(presenter.appImage?.id, person.appPicId)
		XCTAssertEqual(presenter.appImage?.crop, crop)
		XCTAssertEqual(presenter.originalImage?.id, person.appPicId, "The main picture it was framed from stays as the original")
		XCTAssertEqual(presenter.widgetImage?.id, person.widgetPicId, "A widget picture saved earlier may have been framed by hand")
		XCTAssertTrue(presenter.canSave)
	}

	func testAReframedMainPhotoTakesAlongTheWidgetPictureDerivedFromIt() async {
		let person = Person.createPerson()
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		let photo = image(width: 1200, height: 1200)
		presenter.setMainPhoto(FramedPhoto(source: photo, crop: .whole, picture: photo))
		let derived = presenter.widgetImage?.id
		let original = presenter.originalImage?.id
		XCTAssertTrue(presenter.widgetPictureIsDerived)
		let left = PhotoCrop(minX: 0, minY: 0, width: 0.5, height: 1)
		presenter.reframeMainPhoto(FramedPhoto(source: photo, crop: left, picture: image(width: 600, height: 1200)))
		XCTAssertNotEqual(presenter.widgetImage?.id, derived)
		XCTAssertEqual(presenter.widgetImage?.crop, PhotoCrop(minX: 0, minY: 0.25, width: 0.5, height: 0.5), "It follows the new framing")
		XCTAssertEqual(presenter.originalImage?.id, original, "Reframing keeps the original")
		let framed = image(width: 480, height: 480)
		let circle = PhotoCrop(minX: 0.6, minY: 0.1, width: 0.3, height: 0.3)
		presenter.setWidgetPhoto(FramedPhoto(source: photo, crop: circle, picture: framed))
		XCTAssertFalse(presenter.widgetPictureIsDerived)
		presenter.reframeMainPhoto(FramedPhoto(source: photo, crop: .whole, picture: photo))
		XCTAssertTrue(presenter.widgetImage?.uiImage === framed, "A widget picture framed by hand stays")
		XCTAssertEqual(presenter.widgetImage?.crop, circle, "with its own region of the original")
	}
}
