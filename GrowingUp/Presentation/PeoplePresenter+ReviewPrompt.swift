import Foundation

extension PeoplePresenter {
	/// Ends the pause `request` started and says whether to ask for the rating now: only while it is still the waiting
	/// request, the app is active, nothing went wrong meanwhile, and the mosaic shows with nothing over it, not even the
	/// widget hint. A request that may not go is dropped, and a later visit can try again; one that goes is recorded here.
	func takeReviewRequest(_ request: UUID) -> Bool {
		guard let prompter = configurator.reviewPrompter, prompter.takeRequest(request), library.state == .loaded, !isViewing,
			editor == nil, !isReordering, error == nil, !reservesWidgetHint
		else { return false }
		configurator.analytics.track(prompter.recordRequest(people: persons))
		return true
	}
}
