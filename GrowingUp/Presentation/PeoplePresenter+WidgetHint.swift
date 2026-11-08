import Core
import Foundation

extension PeoplePresenter {
	/// Whether the Home Screen widget hint keeps its place in the mosaic. Reordering hides the strip but keeps its place,
	/// so no tile moves as a long press lifts one.
	var reservesWidgetHint: Bool {
		library.state == .loaded && configurator.widgetHinter?.offers(people: persons) == true
	}

	/// Whether the mosaic shows the widget hint now.
	var showsWidgetHint: Bool {
		reservesWidgetHint && !isReordering
	}

	/// Loads the people and, in the same update, gives the widget hint its place, so the mosaic first shows with it.
	func loadWithWidgetHint() async {
		await load()
		revealWidgetHint()
		noteWidgetHintSeen()
	}

	/// The mosaic is on screen: a strip in it now counts toward its launches.
	func noteWidgetHintSeen() {
		guard showsWidgetHint else { return }
		configurator.widgetHinter?.seen()
	}

	/// Gives the widget hint its place in the mosaic when its rules allow it; only while the mosaic is off screen, as
	/// before it first shows or while the viewer covers it, so the strip never appears in front of the user.
	func revealWidgetHint() {
		guard library.state == .loaded else { return }
		configurator.widgetHinter?.reveal(people: persons)
	}

	/// The strip was tapped: returns whether to open the widget guide; the hint is gone for good.
	func openWidgetHint() -> Bool {
		guard showsWidgetHint, let hinter = configurator.widgetHinter else { return false }
		hinter.opened()
		// The guide is no moment for the rating sheet, even once the hint has given up its place.
		configurator.reviewPrompter?.dropPendingRequest()
		return true
	}

	/// × closed the strip: the hint is gone for good.
	func dismissWidgetHint() {
		guard showsWidgetHint else { return }
		configurator.widgetHinter?.dismissed()
	}

	/// The pinned people as the widget shows them, with their widget pictures, for the hint and its guide.
	func widgetPreviewEntry() async -> AgeEntry {
		let pinned = persons.filter(\.isOnWidget)
		let loader = WidgetPersonLoader(fetch: { pinned }, loadImage: configurator.loadImage)
		return AgeEntry(date: configurator.now(), content: await loader.load(limit: Constants.widgetPeopleLimit))
	}
}
