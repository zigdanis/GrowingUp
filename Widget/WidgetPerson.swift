import Core
import UIKit

struct WidgetPerson: Identifiable {
	let id: UUID
	let index: Int
	let name: String
	let birthday: Date
	let image: UIImage?

	var deepLinkURL: URL {
		URL(string: "growingup-app://?\(Constants.widgetPersonIndexKey)=\(index)")!
	}
}
