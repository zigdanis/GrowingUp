import Core
import UIKit

struct WidgetPerson: Identifiable {
	let id: UUID
	let index: Int
	let name: String
	let birthday: Date
	/// The widget image with the legibility scrims drawn in, made once so tiles never redraw it.
	let photo: UIImage?

	var deepLinkURL: URL {
		URL(string: "growingup-app://?\(Constants.widgetPersonIndexKey)=\(index)")!
	}

	init(id: UUID, index: Int, name: String, birthday: Date, image: UIImage?) {
		self.id = id
		self.index = index
		self.name = name
		self.birthday = birthday
		photo = image.map(PhotoScrim.apply)
	}
}
