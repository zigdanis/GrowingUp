/// One picture of the widget guide's illustration.
enum WidgetGuideFrame: Hashable {
	/// Touch and hold an empty spot on the Home Screen.
	case hold
	/// Swipe right on the first Home Screen page, to the Today View.
	case swipe
	/// The icons jiggle; "Edit", then "Add Widget".
	case edit
	/// The widget gallery, with "GrowingUp" typed into its search field.
	case search
	/// GrowingUp's sizes and "Add Widget".
	case size
	/// The medium widget on the Home Screen.
	case homeResult
	/// The large widget in the Today View.
	case todayResult
}
