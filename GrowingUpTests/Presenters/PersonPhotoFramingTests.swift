import Core
import SwiftUI
import XCTest

@testable import GrowingUp

/// A photo kept whole as the original and framed again later, through the stores the app saves to: the main picture
/// and the circle reopen on the regions they show, zooming out reaches what the first crop left out, and every picture
/// is rendered from the original, which is written once, so nothing is lost over repeated edits.
@MainActor
final class PersonPhotoFramingTests: XCTestCase {
	private let phone = CGSize(width: 300, height: 600)
	private let store = MemoryImageStore()
	private lazy var gateway = CachePersonsGateway(
		coreDataGateway: CoreDataPersonsGateway(coreDataStack: InMemoryCoreDataStack()), imageStore: store)
	private lazy var configurator = SceneConfigurator(gateway: gateway, loadImage: store.load, loadOriginal: store.loadOriginal)

	func testATightCropReopensAndZoomsOutToWhatItLeftOut() async throws {
		// A new person's photo, framed tightly inside its red quadrant, as the crop after picking saves it.
		let original = quadrants()
		let pickCrop = CropGeometry(image: original, shape: .rectangle, container: phone, insets: EdgeInsets(), idiom: .phone)
		let tight = await pickCrop.output(of: original, scale: 3, offset: CGSize(width: 337.5, height: 450))
		try assertColor(red, of: tight.picture, at: [CGPoint(x: 0.05, y: 0.05), CGPoint(x: 0.95, y: 0.95)])
		let newPerson = configurator.editor(person: nil, onMutation: { _ in })
		await newPerson.load()
		newPerson.name = "Ada"
		newPerson.setMainPhoto(tight)
		let circle = try XCTUnwrap(newPerson.widgetImage?.crop)
		var person = try await save(newPerson)
		XCTAssertEqual(store.originalWrites, 1)
		XCTAssertTrue(store.contains(person.originalPicId), "The photo is kept whole")
		XCTAssertEqual(person.appPicCrop, tight.crop)
		XCTAssertEqual(person.widgetPicCrop, circle)

		// Reopened, the editor frames the whole original where the main picture shows it.
		var mode = await editMode(for: person)
		XCTAssertEqual(try XCTUnwrap(mode.photo?.cgImage).width, 1200, "The whole original, not the cropped picture")
		assertFraming(mode.framing, scale: 3, offset: CGSize(width: 337.5, height: 450))
		XCTAssertFalse(mode.hasReframed)
		XCTAssertFalse(mode.canSave)
		// Zooming all the way out and moving to the right edge shows the green quadrant the first crop left out.
		mode.magnify(by: 0.1)
		mode.endMagnify()
		mode.drag(by: CGSize(width: -1000, height: 0))
		mode.endDrag()
		assertFraming(mode.framing, scale: 1, offset: CGSize(width: -75, height: 0))
		XCTAssertTrue(mode.canSave)
		person = try await done(mode)
		XCTAssertEqual(person.appPicCrop, PhotoCrop(minX: 1.0 / 3, minY: 0, width: 2.0 / 3, height: 1))
		XCTAssertEqual(person.widgetPicCrop, circle, "The circle keeps its own region")
		XCTAssertEqual(store.originalWrites, 1, "The original is never written again")
		let widened = try await store.load(XCTUnwrap(PersonImage(id: person.appPicId)))
		XCTAssertEqual(widened.cgImage?.width, 800, "Rendered from the original at its resolution, not from the old picture")
		XCTAssertEqual(widened.cgImage?.height, 1600)
		try assertColor(red, of: widened, at: [CGPoint(x: 0.1, y: 0.1)])
		try assertColor(green, of: widened, at: [CGPoint(x: 0.9, y: 0.1)])
		try assertColor(yellow, of: widened, at: [CGPoint(x: 0.9, y: 0.9)])

		// After a relaunch, the editor opens where it was left, and framing tightly again loses nothing.
		mode = await editMode(for: person)
		assertFraming(mode.framing, scale: 1, offset: CGSize(width: -75, height: 0))
		mode.magnify(by: 3)
		mode.endMagnify()
		person = try await done(mode)
		let tightAgain = try await store.load(XCTUnwrap(PersonImage(id: person.appPicId)))
		let expected = try XCTUnwrap(person.appPicCrop).rect(in: CGSize(width: 1200, height: 1600))
		XCTAssertEqual(CGFloat(try XCTUnwrap(tightAgain.cgImage).width), expected.width, accuracy: 1)
		XCTAssertEqual(store.originalWrites, 1)
		XCTAssertEqual(store.files.count, 3, "Only the original and the two current pictures stay stored")
	}

	func testAWidePickerCropReopensWithoutTighteningAfterAFieldEditOrSmallDrag() async throws {
		let window = CGSize(width: 1000, height: 700)
		let original = quadrants()
		let picker = CropGeometry(image: original, shape: .rectangle, container: window, insets: EdgeInsets(), idiom: .phone)
		let picked = await picker.output(of: original, scale: picker.minScale, offset: .zero)
		let editor = configurator.editor(person: nil, onMutation: { _ in })
		await editor.load()
		editor.name = "Wide photo"
		editor.setMainPhoto(picked)
		var person = try await save(editor)
		let pictureID = person.appPicId
		var mode = await editMode(for: person, window: window)
		assertFraming(mode.framing, scale: 0.525, offset: .zero)
		XCTAssertFalse(mode.canSave)
		let photo = try XCTUnwrap(mode.photo)
		let geometry = try XCTUnwrap(mode.geometry(of: photo))
		let visible = try XCTUnwrap(geometry.cropRect(scale: mode.framing.scale, offset: mode.framing.offset))
		XCTAssertEqual(visible.minX, 40, accuracy: 0.001)
		XCTAssertEqual(visible.width, 1120, accuracy: 0.001)
		XCTAssertEqual(visible.height, 1600, accuracy: 0.001)

		// Saving only a field preserves the exact image and crop that the editor previews.
		mode.editor.name = "Wide photo renamed"
		person = try await done(mode)
		XCTAssertEqual(person.appPicId, pictureID)
		XCTAssertEqual(person.appPicCrop, picked.crop)
		mode = await editMode(for: person, window: window)
		assertFraming(mode.framing, scale: 0.525, offset: .zero)

		// A small drag moves the accepted wide crop without unexpectedly zooming it in.
		mode.drag(by: CGSize(width: 1, height: 0))
		mode.endDrag()
		assertFraming(mode.framing, scale: 0.525, offset: CGSize(width: 1, height: 0))
		person = try await done(mode)
		let moved = try XCTUnwrap(person.appPicCrop).rect(in: CropGeometry.pixelSize(of: original))
		XCTAssertLessThan(moved.minX, visible.minX)
		XCTAssertEqual(moved.width, visible.width, accuracy: 0.001)
		XCTAssertEqual(moved.height, visible.height, accuracy: 0.001)
		mode = await editMode(for: person, window: window)
		assertFraming(mode.framing, scale: 0.525, offset: CGSize(width: 1, height: 0))
		XCTAssertEqual(store.originalWrites, 1)
	}

	func testAPhotoPickedBeforeOriginalsWereKeptBecomesTheOriginalWhenFramedAgain() async throws {
		// A stored main picture from an earlier release, with its widget picture, and no original or regions.
		let legacy = PersonImage(uiImage: quadrants())
		let widget = PersonImage(uiImage: quadrants())
		let added = try await gateway.add(
			parameters: AddPersonParameters(
				name: "Ben", dayOfBirth: Date(), timeOfBirth: Date(), appImage: legacy, widgetImage: widget, isOnWidget: false))
		XCTAssertNil(added.originalPicId)
		var mode = await editMode(for: added)
		XCTAssertEqual(mode.framing, .identity, "It opens as the viewer shows it, whole")
		mode.magnify(by: 2)
		mode.endMagnify()
		let person = try await done(mode)
		XCTAssertEqual(person.originalPicId, legacy.id, "The old main picture is kept whole as the original")
		XCTAssertTrue(store.contains(legacy.id))
		XCTAssertNotEqual(person.appPicId, legacy.id)
		XCTAssertEqual(person.widgetPicId, widget.id)
		XCTAssertNil(person.widgetPicCrop, "Its circle's region is unknown, so the circle opens centred")
		XCTAssertEqual(store.originalWrites, 0, "The stored picture is not written again")

		// Reopened, it frames from the old main picture and zooms back out to all of it, though not beyond.
		mode = await editMode(for: person)
		assertFraming(mode.framing, scale: 2, offset: .zero)
		mode.magnify(by: 0.1)
		mode.endMagnify()
		XCTAssertEqual(mode.framing, .identity)
	}

	func testCancelLeavesTheStoredPhotoAsItWas() async throws {
		let original = quadrants()
		let editor = configurator.editor(person: nil, onMutation: { _ in })
		await editor.load()
		editor.name = "Cleo"
		editor.setMainPhoto(.whole(original))
		let person = try await save(editor)
		var cancelled = false
		let mode = PersonEditModePresenter(
			editor: configurator.editor(person: person, onMutation: { _ in }), now: Date.init, onCancel: { cancelled = true })
		await mode.editor.load()
		mode.updateCanvas(phone, safeAreaInsets: EdgeInsets())
		await mode.loadPhoto()
		mode.magnify(by: 2)
		mode.endMagnify()
		mode.editor.setWidgetPhoto(FramedPhoto(source: original, crop: PhotoCrop(minX: 0, minY: 0, width: 0.5, height: 0.375), picture: original))
		mode.cancel()
		XCTAssertTrue(cancelled)
		let people = try await gateway.fetchPersons()
		let stored = try XCTUnwrap(people.first { $0.id == person.id })
		XCTAssertEqual(stored, person, "Nothing reached the store")
		XCTAssertEqual(store.originalWrites, 1)
	}
}

extension PersonPhotoFramingTests {
	private var red: [UInt8] { [255, 0, 0] }
	private var green: [UInt8] { [0, 255, 0] }
	private var yellow: [UInt8] { [255, 255, 0] }

	/// Saves `editor`'s draft and returns the person as stored.
	private func save(_ editor: PersonEditorPresenter) async throws -> Person {
		await editor.save()
		XCTAssertNil(editor.error)
		let people = try await gateway.fetchPersons()
		return try XCTUnwrap(people.last)
	}

	/// Renders `mode`'s framing and saves it, returning the person as stored.
	private func done(_ mode: PersonEditModePresenter) async throws -> Person {
		let id = try XCTUnwrap(mode.editor.person?.id)
		await mode.done()
		XCTAssertNil(mode.editor.error)
		let people = try await gateway.fetchPersons()
		return try XCTUnwrap(people.first { $0.id == id })
	}

	/// The edit mode of the stored `person`, as after a relaunch, with its photo loaded; a phone unless a window is given.
	private func editMode(for person: Person, window: CGSize? = nil) async -> PersonEditModePresenter {
		let mode = PersonEditModePresenter(editor: configurator.editor(person: person, onMutation: { _ in }), now: Date.init, onCancel: {})
		await mode.editor.load()
		mode.updateCanvas(window ?? phone, safeAreaInsets: EdgeInsets())
		await mode.loadPhoto()
		return mode
	}

	private func assertFraming(
		_ framing: PhotoFraming, scale: CGFloat, offset: CGSize, file: StaticString = #filePath, line: UInt = #line
	) {
		XCTAssertEqual(framing.scale, scale, accuracy: 1e-6, file: file, line: line)
		XCTAssertEqual(framing.offset.width, offset.width, accuracy: 1e-6, file: file, line: line)
		XCTAssertEqual(framing.offset.height, offset.height, accuracy: 1e-6, file: file, line: line)
	}

	/// A 1200 × 1600 photo split into red, green, blue and yellow quadrants in reading order.
	private func quadrants() -> UIImage {
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.opaque = true
		format.preferredRange = .standard
		let size = CGSize(width: 1200, height: 1600)
		return UIGraphicsImageRenderer(size: size, format: format).image { context in
			for (index, color) in [UIColor.red, .green, .blue, .yellow].enumerated() {
				color.setFill()
				let origin = CGPoint(x: CGFloat(index % 2) * 600, y: CGFloat(index / 2) * 800)
				context.fill(CGRect(origin: origin, size: CGSize(width: 600, height: 800)))
			}
		}
	}

	/// Checks the colour at each point of `image`, given as fractions of its width and height.
	private func assertColor(
		_ expected: [UInt8], of image: UIImage, at points: [CGPoint], file: StaticString = #filePath, line: UInt = #line
	) throws {
		let pixels = try XCTUnwrap(image.cgImage, file: file, line: line)
		for point in points {
			let column = Int(point.x * CGFloat(pixels.width))
			let row = Int(point.y * CGFloat(pixels.height))
			let actual = try pixel(in: pixels, column: column, row: row)
			let matches = zip(actual, expected).allSatisfy { abs(Int($0) - Int($1)) <= 40 }
			XCTAssertTrue(matches, "Pixel at \(column), \(row) is \(actual), expected \(expected)", file: file, line: line)
		}
	}

	/// Reads one sRGB pixel, addressed from the top-left corner.
	private func pixel(in pixels: CGImage, column: Int, row: Int) throws -> [UInt8] {
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
}
