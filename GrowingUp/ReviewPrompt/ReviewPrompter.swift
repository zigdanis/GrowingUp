import Core
import Foundation

/// Counts days of use and visits to the viewer, notes setbacks, and decides when the app asks for an App Store rating.
/// The decision rules live in `ReviewPromptPolicy`; this keeps the stored state and the session.
@MainActor
final class ReviewPrompter {
	private let store: ReviewPromptStore
	private let policy: ReviewPromptPolicy
	private let mode: ReviewPromptMode
	private let version: String
	private let now: () -> Date
	private let calendar: Calendar
	/// When the open viewer began showing people; nil while none is open.
	private var viewerOpened: Date?
	/// A failed operation or a removal this session: not a moment to ask.
	private(set) var hadSetbackThisSession = false
	private var requestedThisSession = false

	init(
		store: ReviewPromptStore, mode: ReviewPromptMode = .policy, policy: ReviewPromptPolicy = ReviewPromptPolicy(),
		version: String = ReviewPrompter.bundleVersion, now: @escaping () -> Date = Date.init,
		calendar: Calendar = .autoupdatingCurrent
	) {
		self.store = store
		self.mode = mode
		self.policy = policy
		self.version = version
		self.now = now
		self.calendar = calendar
	}

	nonisolated static var bundleVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
	}

	func appBecameActive() {
		update { policy.recordingActiveDay($0, now: now(), calendar: calendar) }
	}

	/// The app left the screen; the next foreground use is a new session.
	func appEnteredBackground() {
		hadSetbackThisSession = false
		requestedThisSession = false
	}

	func noteSetback() {
		hadSetbackThisSession = true
	}

	/// The viewer began showing people, from a tile or a widget link.
	func viewerOpened(replacingNewPerson: Bool = false) {
		if viewerOpened == nil || replacingNewPerson { viewerOpened = now() }
	}

	/// The cover turned into a new person's empty page, which is no visit to anyone.
	func viewerLeftForNewPerson() {
		viewerOpened = nil
	}

	/// Counts a closed viewer that showed someone long enough and reports whether this is the moment to ask, with
	/// `people` everyone stored now.
	func viewerClosed(people: [Person]) -> Bool {
		guard let opened = viewerOpened else { return false }
		viewerOpened = nil
		let closed = now()
		guard policy.isVisit(from: opened, to: closed) else { return false }
		// A session that runs past midnight is already on the next day of use.
		update { policy.recordingViewerVisit(policy.recordingActiveDay($0, now: closed, calendar: calendar)) }
		guard !hadSetbackThisSession else { return false }
		switch mode {
		case .forced:
			return true
		case .policy:
			return !requestedThisSession
				&& policy.shouldRequest(store.state, now: closed, calendar: calendar, version: version, people: people)
		}
	}

	/// Records a request handed to the system and returns its analytics event; a forced check stores nothing.
	func recordRequest(people: [Person]) -> AnalyticsEvent {
		let date = now()
		var state = store.state
		state = policy.recordingRequest(state, now: date, version: version)
		if mode == .policy {
			requestedThisSession = true
			store.state = state
		}
		return .reviewPromptRequested(
			activeDays: state.activeDays,
			daysSinceFirstActive: policy.daysSinceFirstActive(state, now: date, calendar: calendar),
			viewerVisits: state.viewerVisits,
			peopleWithPhotoCount: people.filter(\.hasPhoto).count,
			requestNumber: state.requestCount)
	}

	private func update(_ change: (ReviewPromptState) -> ReviewPromptState) {
		store.state = change(store.state)
	}
}
