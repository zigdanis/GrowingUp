import Foundation

public struct PersonImages: Sendable {
	public var appPic: PersonImage?
	public var widgetPic: PersonImage?

	public init(appPic: PersonImage?, widgetPic: PersonImage?) {
		self.appPic = appPic
		self.widgetPic = widgetPic
	}

	public static func emptyImages() -> PersonImages {
		PersonImages(appPic: nil, widgetPic: nil)
	}
}
