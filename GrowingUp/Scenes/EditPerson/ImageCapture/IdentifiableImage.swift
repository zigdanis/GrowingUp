import UIKit

struct IdentifiableImage: Identifiable {
	let id = UUID()
	let image: UIImage
}
