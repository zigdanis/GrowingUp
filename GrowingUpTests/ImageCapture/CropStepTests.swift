//
//  CropStepTests.swift
//  GrowingUpTests
//
//  Covers the limits applied when VoiceOver moves, zooms or resets the crop.
//

import SwiftUI
import UIKit
import XCTest

@testable import GrowingUp

@MainActor
final class CropStepTests: XCTestCase {
	private let container = CGSize(width: 400, height: 800)
	private let insets = EdgeInsets()

	/// A 2:1 landscape photo, so it fills the portrait frame by height and has room to move sideways.
	private func makeCropStep(shape: CropShape = .rectangle) -> CropStep {
		let format = UIGraphicsImageRendererFormat.default()
		format.scale = 1
		let image = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000), format: format).image { context in
			UIColor.red.setFill()
			context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
		}
		return CropStep(image: image, shape: shape, onComplete: { _ in }, onCancel: {})
	}

	func testZoomIsLimitedToTheMinimumAndMaximum() {
		let step = makeCropStep()
		let minimum = step.minScale(in: container, insets: insets)

		let zoomedOut = step.settledCrop(scale: minimum / 2, offset: .zero, container: container, insets: insets)
		XCTAssertEqual(zoomedOut.scale, minimum, accuracy: 0.0001)

		let zoomedIn = step.settledCrop(scale: step.maxZoom * 2, offset: .zero, container: container, insets: insets)
		XCTAssertEqual(zoomedIn.scale, step.maxZoom, accuracy: 0.0001)
	}

	func testOffsetStaysWhereThePhotoCoversTheFrame() {
		let step = makeCropStep()
		let minimum = step.minScale(in: container, insets: insets)
		let bounds = step.offsetBounds(scale: minimum, container: container, insets: insets)
		XCTAssertGreaterThan(bounds.x.upperBound, 0)

		let far = CGSize(width: 10_000, height: -10_000)
		let settled = step.settledCrop(scale: minimum, offset: far, container: container, insets: insets)
		XCTAssertEqual(settled.offset.width, bounds.x.upperBound, accuracy: 0.0001)
		XCTAssertEqual(settled.offset.height, bounds.y.lowerBound, accuracy: 0.0001)
	}

	func testZoomingOutPullsTheOffsetBackInsideTheSmallerBounds() {
		let step = makeCropStep()
		let minimum = step.minScale(in: container, insets: insets)
		let zoomedBounds = step.offsetBounds(scale: minimum * 3, container: container, insets: insets)
		let atEdge = CGSize(width: zoomedBounds.x.upperBound, height: 0)

		let settled = step.settledCrop(scale: minimum, offset: atEdge, container: container, insets: insets)
		XCTAssertEqual(settled.offset.width, step.offsetBounds(scale: minimum, container: container, insets: insets).x.upperBound, accuracy: 0.0001)
		XCTAssertLessThan(settled.offset.width, atEdge.width)
	}

	func testResetSettlesAtTheMinimumZoomCentred() {
		let step = makeCropStep(shape: .circle)
		let reset = step.settledCrop(scale: 0, offset: .zero, container: container, insets: insets)
		XCTAssertEqual(reset.scale, step.minScale(in: container, insets: insets), accuracy: 0.0001)
		XCTAssertEqual(reset.offset, step.clampOffset(.zero, scale: reset.scale, container: container, insets: insets))
	}
}
