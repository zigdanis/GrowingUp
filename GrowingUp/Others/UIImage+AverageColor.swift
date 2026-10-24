import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

extension UIImage {
	private static let averagingContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])

	/// The image's mean colour in sRGB, from Core Image's area average; nil for an image without bitmap data.
	///
	/// It reads every pixel once, so callers compute it once per picture rather than while drawing.
	var averageColor: UIColor? {
		guard let input = cgImage.map({ CIImage(cgImage: $0) }) ?? ciImage else { return nil }
		let filter = CIFilter.areaAverage()
		filter.inputImage = input
		filter.extent = input.extent
		guard let output = filter.outputImage else { return nil }
		var pixel = [UInt8](repeating: 0, count: 4)
		Self.averagingContext.render(
			output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8,
			colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
		return UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
	}
}
