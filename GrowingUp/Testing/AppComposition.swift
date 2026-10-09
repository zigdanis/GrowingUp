import Core
import Foundation
import UIKit

@MainActor
enum AppComposition {
	static func make(for launchMode: AppLaunchMode) -> SceneConfigurator {
		switch launchMode {
		case .live:
			return .live()
		#if DEBUG
			case let .uiTest(configuration):
				do {
					return try makeUITestComposition(configuration)
				} catch {
					fatalError("UI test store failed: \(error)")
				}
		#endif
		}
	}

	#if DEBUG
		private static let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

		private static func makeUITestComposition(_ configuration: UITestConfiguration) throws -> SceneConfigurator {
			let root = URL.applicationSupportDirectory.appendingPathComponent("UITests/\(configuration.identifier)")
			if configuration.resetStore, FileManager.default.fileExists(atPath: root.path) {
				try FileManager.default.removeItem(at: root)
			}
			try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
			let stack = try UITestStore(url: root.appendingPathComponent("people.sqlite"))
			if configuration.resetStore, configuration.seed != .empty { try stack.seed(configuration.seed) }
			let images = UITestImageStore(root: root)
			let persistentGateway = CoreDataPersonsGateway(coreDataStack: stack)
			let failureGateway = UITestFailureGateway(base: persistentGateway, failNextSave: configuration.failNextSave)
			let gateway = CachePersonsGateway(coreDataGateway: failureGateway, imageStore: images)
			let environment = ProcessInfo.processInfo.environment
			let clockDate = environment["GROWINGUP_BIRTHDAY_NOW"].flatMap(ISO8601DateFormatter().date(from:)) ?? fixedDate
			let clockStarted = Date()
			let clockRuns = environment["GROWINGUP_BIRTHDAY_CLOCK_RUNNING"] == "1"
			return SceneConfigurator(
				gateway: gateway, loadImage: images.load,
				now: { clockDate.addingTimeInterval(clockRuns ? Date().timeIntervalSince(clockStarted) : 0) },
				photoFixtures: try photoFixtures(environment: environment))
		}

		private static func photoFixtures(environment: [String: String]) throws -> [UIImage] {
			guard environment["GROWINGUP_APP_STORE_CAPTURE"] == "1" else { return (0..<18).map(fixture) }
			guard let directory = environment["GROWINGUP_APP_STORE_PHOTOS"] else { throw CocoaError(.fileNoSuchFile) }
			return try ["baby-girl", "young-boy", "cat", "dog"].map { name in
				let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
				let data = try Data(contentsOf: url)
				guard let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
				return image
			}
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
	#endif
}
