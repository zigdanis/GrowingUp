import Foundation

/// Where an export stands, from the person's tap to the file the share sheet offers; a failed one is idle again, with an
/// alert to explain it.
enum FileExport: Equatable {
	case idle
	/// The file is being written; it takes a moment with many photos.
	case preparing
	/// The file at this location is ready to share or save; nothing has left the device.
	case ready(URL)
}
