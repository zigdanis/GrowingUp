import XCTest

@testable import GrowingUp

/// The widget guide's steps and pictures: a beat per step, then the result, and a tapped step or tab plays from there.
final class WidgetGuidePlaybackTests: XCTestCase {
	func testTheHomeScreenTabPlaysItsStepsThenTheResultAndStartsOver() {
		var playback = WidgetGuidePlayback()
		var seen: [(Int, WidgetGuideFrame)] = []
		for _ in 0..<6 {
			seen.append((playback.step, playback.frame))
			playback.advance()
		}
		XCTAssertEqual(seen.map(\.0), [0, 1, 2, 3, 3, 0], "The result keeps the last step highlighted")
		XCTAssertEqual(seen.map(\.1), [.hold, .edit, .search, .size, .homeResult, .hold])
	}

	func testTheTodayViewTabStartsWithASwipeAndEndsInTheTodayView() {
		var playback = WidgetGuidePlayback()
		playback.advance()
		playback.show(.todayView)
		XCTAssertEqual(playback.step, 0, "Another tab plays from its first step")
		XCTAssertEqual(playback.frame, .swipe)
		playback.jump(to: 3)
		playback.advance()
		XCTAssertEqual(playback.frame, .todayResult)
	}

	func testATappedStepShowsItsOwnPicture() {
		var playback = WidgetGuidePlayback()
		let frames = (0..<4).map { step -> WidgetGuideFrame in
			playback.jump(to: step)
			return playback.frame
		}
		XCTAssertEqual(frames, [.hold, .edit, .search, .size])
		playback.jump(to: 9)
		XCTAssertEqual(playback.step, 3)
		playback.show(.homeScreen)
		XCTAssertEqual(playback.step, 3, "The tab already shown keeps its step")
	}
}
