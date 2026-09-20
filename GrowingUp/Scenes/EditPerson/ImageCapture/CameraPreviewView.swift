import AVFoundation
import UIKit

/// A UIView backed by an AVCaptureVideoPreviewLayer so layout drives the layer's frame.
final class CameraPreviewView: UIView {
	// `layerClass` is a UIKit override point, not an instance-independent constant.
	// swiftlint:disable:next static_over_final_class
	override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

	var videoPreviewLayer: AVCaptureVideoPreviewLayer {
		// swiftlint:disable:next force_cast
		layer as! AVCaptureVideoPreviewLayer
	}
}
