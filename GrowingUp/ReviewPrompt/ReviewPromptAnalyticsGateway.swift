/// Passes everything on to `base` and tells the review prompter about setbacks on the way: every handled failure, from
/// the mosaic or an editor, and every removal. All of them already travel through the one analytics gateway, so a
/// new kind of failure keeps the rating request away without further wiring.
@MainActor
final class ReviewPromptAnalyticsGateway: AnalyticsGateway {
	private let base: AnalyticsGateway
	private let prompter: ReviewPrompter

	init(base: AnalyticsGateway, prompter: ReviewPrompter) {
		self.base = base
		self.prompter = prompter
	}

	func track(_ event: AnalyticsEvent) {
		if case .personRemoved = event { prompter.noteSetback() }
		base.track(event)
	}

	func report(_ failure: AnalyticsFailure) {
		prompter.noteSetback()
		base.report(failure)
	}

	func update(_ context: AnalyticsContext) {
		base.update(context)
	}
}
