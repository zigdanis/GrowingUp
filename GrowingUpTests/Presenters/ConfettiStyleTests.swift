import XCTest

@testable import GrowingUp

final class ConfettiStyleTests: XCTestCase {
	private let screen = CGSize(width: 393, height: 852)

	func testCelebrationsRotateThroughEveryStyleStartingWithPoppers() {
		XCTAssertEqual((1...4).map(ConfettiStyle.init(celebration:)), [.poppers, .rain, .fireworks, .poppers])
		XCTAssertEqual(ConfettiStyle(celebration: 0), .fireworks)
	}

	func testSameSeedReproducesTheSameBurst() {
		for style in ConfettiStyle.allCases {
			let first = style.particles(seed: 7).map { $0.position(at: 1, in: screen) }
			let second = style.particles(seed: 7).map { $0.position(at: 1, in: screen) }
			XCTAssertEqual(first, second, "\(style)")
			XCTAssertNotEqual(first, style.particles(seed: 8).map { $0.position(at: 1, in: screen) }, "\(style)")
		}
	}

	func testEveryParticleAppearsAndIsGoneBeforeTheOverlayIsRemoved() {
		for style in ConfettiStyle.allCases {
			let particles = style.particles(seed: 1)
			XCTAssertFalse(particles.isEmpty)
			for particle in particles {
				XCTAssertGreaterThanOrEqual(particle.delay, 0, "\(style)")
				XCTAssertLessThanOrEqual(particle.delay + particle.lifetime, ConfettiStyle.duration + 1e-9, "\(style)")
				XCTAssertEqual(particle.opacity(at: -0.01), 0)
				XCTAssertEqual(particle.opacity(at: particle.lifetime + 0.01), 0)
			}
			XCTAssertTrue(particles.contains { $0.opacity(at: 0.5 - $0.delay) > 0 }, "\(style) must be visible right away")
		}
	}

	func testPoppersRiseFromTheBottomCornersIntoTheUpperScreen() {
		let particles = ConfettiStyle.poppers.particles(seed: 1)
		for particle in particles {
			let start = particle.position(at: 0, in: screen)
			XCTAssertGreaterThan(start.y, screen.height)
			XCTAssertTrue(start.x < 0 || start.x > screen.width)
		}
		let highest = particles.map { $0.position(at: 1, in: screen).y }.min() ?? screen.height
		XCTAssertLessThan(highest, screen.height * 0.35)
	}

	func testRocketsStopWhereTheirShellBursts() throws {
		let particles = ConfettiStyle.fireworks.particles(seed: 1)
		let rockets = particles.filter { $0.shape == .rocket }
		XCTAssertEqual(rockets.count, 4)
		for rocket in rockets {
			let burstTime = rocket.delay + rocket.lifetime
			let shell = try XCTUnwrap(particles.first { $0.shape == .spark && abs($0.delay - burstTime) < 1e-9 })
			let top = rocket.position(at: rocket.lifetime, in: screen)
			XCTAssertEqual(top.x, shell.origin.x * screen.width, accuracy: 0.5)
			XCTAssertEqual(top.y, shell.origin.y * screen.height, accuracy: 0.5)
		}
	}
}
