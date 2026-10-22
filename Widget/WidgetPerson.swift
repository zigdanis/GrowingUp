import Core
import UIKit

struct WidgetPerson: Identifiable {
	let id: UUID
	let index: Int
	let name: String
	let birthday: Date
	/// The widget image with the legibility scrims drawn in, made once so tiles never redraw it.
	let photo: UIImage?
	/// What a Home Screen tile shows: the photo, or the person's monogram when they have none, with the same scrims.
	let tilePicture: UIImage

	var deepLinkURL: URL {
		URL(string: "growingup-app://?\(Constants.widgetPersonIDKey)=\(id.uuidString)")!
	}

	init(id: UUID, index: Int, name: String, birthday: Date, image: UIImage?) {
		self.id = id
		self.index = index
		self.name = name
		self.birthday = birthday
		photo = image.map(PhotoScrim.apply)
		tilePicture = photo ?? PhotoScrim.apply(to: MonogramPicture.draw(id: id, name: name))
	}
}
