import UIKit

/// How a person page arranges itself in its window, measured from the window and never from the device; only whether
/// the window spans a fold comes from the device.
///
/// Every supported iPhone is at most 440 pt wide, so it always gets `phone`; the wider shapes come from iPhone Duo,
/// whose window can change shape mid-session when it folds or unfolds, and from iPad.
enum PersonPageLayout: Equatable {
	/// One column over a full-bleed photo, as on every iPhone; also narrow Split View.
	case phone
	/// A wide upright window, such as either iPhone Duo display held in portrait or an iPad: the phone layout in a column.
	case widePortrait
	/// A window at least as wide as it is tall: the photo on the leading half, the age and controls on the trailing half.
	case landscape

	/// Windows narrower than this keep the phone layout whatever their height.
	static let phoneWidthLimit: CGFloat = 450

	/// The widest the age, the birthday card and the avatar strip get; nil keeps the phone's full width.
	var columnWidth: CGFloat? {
		switch self {
		case .phone: return nil
		case .widePortrait: return 600
		case .landscape: return 480
		}
	}

	init(window: CGSize) {
		if window.width < Self.phoneWidthLimit {
			self = .phone
		} else if window.width >= window.height {
			self = .landscape
		} else {
			self = .widePortrait
		}
	}

	/// Whether a window of this layout may span a fold: a wide window on a phone is an iPhone Duo's, which folds down its
	/// middle, while an iPad's never folds.
	func spansFold(idiom: UIUserInterfaceIdiom) -> Bool {
		self != .phone && idiom == .phone
	}
}
