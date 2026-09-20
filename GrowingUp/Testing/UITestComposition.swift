#if DEBUG
	import Core
	import SwiftUI
	import UIKit

	/// Explicit opt-in composition: every UI test gets its own SQLite and image directory.
	@MainActor
	enum UITestComposition {
		static var isEnabled: Bool {
			guard let value = ProcessInfo.processInfo.environment["GROWINGUP_UI_TEST_ID"] else { return false }
			return UUID(uuidString: value) != nil
		}

		static var colorScheme: ColorScheme? {
			guard isEnabled else { return nil }
			return ProcessInfo.processInfo.environment["GROWINGUP_UI_APPEARANCE"] == "Dark" ? .dark : .light
		}

		static let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

		static func make() throws -> SceneConfigurator? {
			let environment = ProcessInfo.processInfo.environment
			guard let identifier = environment["GROWINGUP_UI_TEST_ID"], UUID(uuidString: identifier) != nil else { return nil }
			let root = URL.applicationSupportDirectory.appendingPathComponent("UITests/\(identifier)")
			if environment["GROWINGUP_UI_RESET"] == "1", FileManager.default.fileExists(atPath: root.path) {
				try FileManager.default.removeItem(at: root)
			}
			try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
			let stack = try UITestStore(url: root.appendingPathComponent("people.sqlite"))
			if environment["GROWINGUP_UI_RESET"] == "1", environment["GROWINGUP_UI_SEED"] == "pinned" { try stack.seed() }
			let images = UITestImageStore(root: root)
			let persistentGateway = CoreDataPersonsGateway(coreDataStack: stack)
			let failureGateway = UITestFailureGateway(
				base: persistentGateway, failNextSave: environment["GROWINGUP_UI_FAIL_SAVE"] == "1")
			let gateway = CachePersonsGateway(coreDataGateway: failureGateway, imageStore: images)
			return SceneConfigurator(
				gateway: gateway, loadImage: images.load, now: { fixedDate }, photoFixtures: (0..<18).map(fixture))
		}

		private static func fixture(_ index: Int) -> UIImage {
			let size = CGSize(width: 900, height: 1200)
			let format = UIGraphicsImageRendererFormat()
			format.scale = 1
			return UIGraphicsImageRenderer(size: size, format: format).image { context in
				let colors: [UIColor] = [.systemTeal, .systemBlue, .systemIndigo]
				colors[index % colors.count].setFill()
				context.fill(CGRect(origin: .zero, size: size))
				UIColor.systemYellow.setFill()
				context.cgContext.fillEllipse(in: CGRect(x: 540, y: 90, width: 200, height: 200))
				for row in 0..<8 {
					let path = UIBezierPath()
					let top = CGFloat(330 + row * 110)
					path.move(to: CGPoint(x: 0, y: top + 200))
					path.addLine(to: CGPoint(x: 280, y: top))
					path.addLine(to: CGPoint(x: 550, y: top + 150))
					path.addLine(to: CGPoint(x: 780, y: top - 60))
					path.addLine(to: CGPoint(x: 900, y: top + 100))
					path.addLine(to: CGPoint(x: 900, y: 1200))
					path.addLine(to: CGPoint(x: 0, y: 1200))
					path.close()
					UIColor(
						hue: 0.35 + Double(row) * 0.015, saturation: 0.65,
						brightness: 0.7 - Double(row) * 0.06, alpha: 1
					).setFill()
					path.fill()
				}
			}
		}
	}
#endif
