import Core
import Foundation
import Observation

/// Counts days of use and visits to the viewer, notes setbacks, and decides when the app asks for an App Store rating.
/// The decision rules live in `ReviewPromptPolicy`; this keeps the stored state and the session.
@MainActor
@Observable
final class ReviewPrompter {
	private let store: ReviewPromptStore
	private let policy: ReviewPromptPolicy
	private let mode: ReviewPromptMode
	private let version: String
	private let now: () -> Date
	private let calendar: Calendar
	/// When the open viewer began showing people, or the app last came back to it; nil while none is open.
	private var visitStarted: Date?
	/// The state of a forced check, which never reaches the store.
	private var forcedState = ReviewPromptState()
	/// An alert or a removal this session: not a moment to ask.
	private(set) var hadSetbackThisSession = false
	private var requestedThisSession = false
	/// Whether the app is in the foreground, as the scene last reported.
	private var isAppActive = false
	/// A request a closed viewer started, which the scene makes after a pause; see `takeRequest(_:)`. Every request is a
	/// new value, so the scene's wait restarts with it.
	private(set) var pendingRequest: UUID?

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
		isAppActive = true
		// Time away from the app is no time spent looking at someone.
		if visitStarted != nil { visitStarted = now() }
		update { policy.recordingActiveDay($0, now: now(), calendar: calendar) }
	}

	/// Control Center, a notification or the app switcher covers the app: a waiting request is dropped.
	func appResignedActive() {
		isAppActive = false
		pendingRequest = nil
	}

	/// The app left the screen; the next foreground use is a new session.
	func appEnteredBackground() {
		appResignedActive()
		hadSetbackThisSession = false
		requestedThisSession = false
	}

	func noteSetback() {
		hadSetbackThisSession = true
	}

	/// The viewer began showing people, from a tile or a widget link.
	func viewerOpened(replacingNewPerson: Bool = false) {
		// A request still waiting for its pause is no longer the moment: the user moved on.
		pendingRequest = nil
		if visitStarted == nil || replacingNewPerson { visitStarted = now() }
	}

	/// Something else took the screen, such as the widget guide: a request still waiting for its pause is dropped, and a
	/// later visit can try again.
	func dropPendingRequest() {
		pendingRequest = nil
	}

	/// The cover turned into a new person's empty page, which is no visit to anyone.
	func viewerLeftForNewPerson() {
		pendingRequest = nil
		visitStarted = nil
	}

	/// Counts a closed viewer that showed someone long enough and, when this is the moment to ask, starts a request and
	/// returns true; `people` are everyone stored now.
	@discardableResult
	func viewerClosed(people: [Person]) -> Bool {
		let asks = isMoment(people: people)
		if asks { pendingRequest = UUID() }
		return asks
	}

	/// Ends the pause `request` started and says whether it may still go: only while it is the waiting request, the app
	/// is active and nothing went wrong meanwhile. Either way it is no longer waiting.
	func takeRequest(_ request: UUID) -> Bool {
		guard pendingRequest == request else { return false }
		pendingRequest = nil
		return isAppActive && !hadSetbackThisSession
	}

	private func isMoment(people: [Person]) -> Bool {
		guard let opened = visitStarted else { return false }
		visitStarted = nil
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
				&& policy.shouldRequest(state, now: closed, calendar: calendar, version: version, people: people)
		}
	}

	/// Records a request handed to the system and returns its analytics event.
	func recordRequest(people: [Person]) -> AnalyticsEvent {
		let date = now()
		if mode == .policy { requestedThisSession = true }
		update { policy.recordingRequest($0, now: date, version: version) }
		let state = self.state
		return .reviewPromptRequested(
			activeDays: state.activeDays,
			daysSinceFirstActive: policy.daysSinceFirstActive(state, now: date, calendar: calendar),
			viewerVisits: state.viewerVisits,
			peopleWithPhotoCount: people.filter(\.hasPhoto).count,
			requestNumber: state.requestCount)
	}

	/// The stored state, or a forced check's own, which starts from nothing and never reaches the store.
	private var state: ReviewPromptState {
		get { mode == .forced ? forcedState : store.state }
		set {
			if mode == .forced { forcedState = newValue } else { store.state = newValue }
		}
	}

	private func update(_ change: (ReviewPromptState) -> ReviewPromptState) {
		state = change(state)
	}
}
