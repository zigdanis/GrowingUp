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
		XCTAssertTrue(presenter.isDirty)
		XCTAssertFalse(presenter.canSave)
		presenter.name = ""
		XCTAssertFalse(presenter.isDirty)
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
		presenter.hasBirthTime = true
		XCTAssertEqual(presenter.birthday, midnight, "Turning the time on keeps midnight until a time is picked")
		XCTAssertFalse(presenter.isDirty)
		presenter.timeOfBirth = date(year: 2024, month: 5, day: 6, hour: 14, minute: 30).addingTimeInterval(45)
		XCTAssertEqual(presenter.birthday, date(year: 2020, month: 1, day: 2, hour: 14, minute: 30))
		XCTAssertTrue(presenter.isDirty)
		presenter.hasBirthTime = false
		XCTAssertEqual(presenter.birthday, midnight)
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
		presenter.setMainPhoto(photo)
		XCTAssertTrue(presenter.appImage?.uiImage === photo)
		let widgetPixels = presenter.widgetImage?.uiImage?.cgImage
		XCTAssertEqual(widgetPixels?.width, Int(WidgetPictureDeriver.maxPixelSide))
		XCTAssertEqual(widgetPixels?.height, Int(WidgetPictureDeriver.maxPixelSide))
		XCTAssertNotEqual(presenter.appImage?.id, presenter.widgetImage?.id)
		XCTAssertTrue(presenter.canSave)
	}

	func testRemovingTheMainPhotoClearsBothPictures() async {
		let person = Person.createPerson()
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		presenter.removeMainPhoto()
		XCTAssertNil(presenter.appImage)
		XCTAssertNil(presenter.widgetImage)
		XCTAssertTrue(presenter.canSave)
	}

	func testReframingReplacesOnlyTheWidgetPicture() async {
		let person = Person.createPerson()
		let presenter = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: person, onMutation: { _ in })
		await presenter.load()
		let reframed = image(width: 480, height: 480)
		presenter.setWidgetPhoto(reframed)
		XCTAssertEqual(presenter.appImage?.id, person.appPicId)
		XCTAssertNotEqual(presenter.widgetImage?.id, person.widgetPicId)
		XCTAssertTrue(presenter.widgetImage?.uiImage === reframed)
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

	func testMainPhotoForReframingPrefersThePickedImageAndReportsLoadFailures() async {
		let stored = image(width: 600, height: 800)
		var loads = 0
		let loader = SceneConfigurator(gateway: PersonsGatewaySpy(), loadImage: { _ in
			loads += 1
			return stored
		})
		let presenter = loader.editor(person: .createPerson(), onMutation: { _ in })
		let loaded = await presenter.loadMainPhoto()
		XCTAssertTrue(loaded === stored)
		let picked = image(width: 900, height: 1200)
		presenter.setMainPhoto(picked)
		let reused = await presenter.loadMainPhoto()
		XCTAssertTrue(reused === picked)
		XCTAssertEqual(loads, 1)
		let failing = SceneConfigurator(gateway: PersonsGatewaySpy(), loadImage: { _ in throw CoreError.missingValue })
		let failed = failing.editor(person: .createPerson(), onMutation: { _ in })
		let missing = await failed.loadMainPhoto()
		XCTAssertNil(missing)
		XCTAssertEqual(failed.error?.message, CoreError.missingValue.message)
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
