import Core
import SwiftUI
import XCTest

@testable import GrowingUp

/// What edit mode shows in place of a main photo: the widget picture alone, as it is, as the person's page shows it, or
/// else the monogram; only a main photo is framed.
@MainActor
final class PersonEditModePictureTests: XCTestCase {
	private let phone = CGSize(width: 300, height: 600)

	func testAWidgetPictureAloneStaysAsThePageShowedItUntilAMainPhotoIsPicked() async throws {
		var person = Person.createPerson()
		person.appPicId = nil
		let widgetPicture = image(width: 600, height: 600)
		let mode = mode(for: person, photo: widgetPicture)
		XCTAssertFalse(mode.showsMonogram, "Entering edit mode never flashes the monogram over the page's picture")
		await mode.editor.load()
		await mode.loadPhoto()
		mode.updateCanvas(phone, safeAreaInsets: EdgeInsets())
		XCTAssertTrue(mode.backdrop === widgetPicture, "Edit mode keeps showing what the page showed")
		XCTAssertNil(mode.photo)
		XCTAssertFalse(mode.showsMonogram)
		XCTAssertFalse(mode.showsWidgetPictureButton, "Only a main photo frames a widget picture")
		mode.drag(by: CGSize(width: 40, height: 0))
		mode.endDrag()
		XCTAssertFalse(mode.hasReframed, "Only a main photo is framed")
		XCTAssertFalse(mode.canSave)
		mode.editor.setMainPhoto(image(width: 900, height: 1200))
		await mode.loadPhoto()
		XCTAssertNotNil(mode.photo)
		XCTAssertNil(mode.backdrop)
		XCTAssertTrue(mode.showsWidgetPictureButton)
		mode.editor.removeMainPhoto()
		await mode.loadPhoto()
		XCTAssertNil(mode.backdrop)
		XCTAssertTrue(mode.showsMonogram, "With no picture left, the monogram shows")
	}

	func testRemovingAWidgetPictureShownAloneLeavesTheMonogram() async throws {
		var person = Person.createPerson()
		person.appPicId = nil
		let gateway = savingGateway(for: person)
		let mode = mode(for: person, gateway: gateway)
		await mode.editor.load()
		await mode.loadPhoto()
		XCTAssertNotNil(mode.backdrop)
		mode.editor.removeMainPhoto()
		await mode.loadPhoto()
		XCTAssertNil(mode.backdrop)
		XCTAssertTrue(mode.showsMonogram)
		XCTAssertTrue(mode.canSave, "Removing the picture is a change")
		await mode.done()
		XCTAssertNil(gateway.addPersonParameters.widgetImage)
	}

	func testOnlyAPersonWithoutAnyPictureShowsTheMonogram() async throws {
		var bare = Person.createPerson()
		bare.appPicId = nil
		bare.widgetPicId = nil
		let monogram = mode(for: bare)
		XCTAssertTrue(monogram.showsMonogram, "At once, as the page shows it")
		await monogram.loadPhoto()
		XCTAssertTrue(monogram.showsMonogram)
		XCTAssertNil(monogram.backdrop)
		let photographed = mode(for: Person.createPerson())
		XCTAssertFalse(photographed.showsMonogram)
		await photographed.loadPhoto()
		XCTAssertNotNil(photographed.photo)
		XCTAssertNil(photographed.backdrop)
		XCTAssertFalse(photographed.showsMonogram)
		let editor = SceneConfigurator(gateway: PersonsGatewaySpy()).editor(person: nil, onMutation: { _ in })
		let newPerson = PersonEditModePresenter(editor: editor, now: Date.init, onCancel: {})
		await newPerson.loadPhoto()
		XCTAssertFalse(newPerson.showsMonogram, "A new person's draft lies on the glow")
		XCTAssertNil(newPerson.backdrop)
	}

	private func mode(for person: Person, gateway: PersonsGatewaySpy = PersonsGatewaySpy(), photo: UIImage? = nil) -> PersonEditModePresenter {
		let configurator = SceneConfigurator(gateway: gateway, loadImage: { _ in photo ?? self.image(width: 600, height: 800) })
		let editor = configurator.editor(person: person, onMutation: { _ in })
		return PersonEditModePresenter(editor: editor, now: Date.init, onCancel: {})
	}

	/// A gateway that saves `person` and lists only them.
	private func savingGateway(for person: Person) -> PersonsGatewaySpy {
		let gateway = PersonsGatewaySpy()
		gateway.fetchPersonsResultToBeReturned = .success([person])
		gateway.editPersonResultToBeReturned = .success(person)
		return gateway
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
