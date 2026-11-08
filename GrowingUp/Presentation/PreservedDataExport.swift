import Foundation

/// Where an export of preserved data stands, from the person's tap to the archive the share sheet offers; a failed one
/// is idle again, with `PreservedDataFailure.export` to explain it.
enum PreservedDataExport: Equatable {
	case idle
	/// The archive is being written; it takes a moment with many photos.
	case preparing
	/// The archive at this location is ready to share or save; nothing has left the device.
	case ready(URL)
}
