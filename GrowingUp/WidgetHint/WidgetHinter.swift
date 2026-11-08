import Core
import Foundation
import Observation

/// Decides when the mosaic shows the strip that points to the Home Screen widget, and remembers when it ends.
/// The rules live in `WidgetHintPolicy`; this keeps the stored state, the session and the widget lookup.
///
/// The strip takes its place only while the mosaic is off screen: before it first appears, or while the viewer covers it
/// (see `reveal(people:)`). So it is already there when the mosaic shows and is never animated in.
@MainActor
@Observable
final class WidgetHinter {
	private let store: WidgetHintStore
	private let usage: () -> ReviewPromptState
	private let policy: WidgetHintPolicy
	private let mode: WidgetHintMode
	private let lookUpWidget: () async -> Bool?
	private let analytics: AnalyticsGateway
	private let now: () -> Date
	private let calendar: Calendar
	/// The state of a forced check, which never reaches the store.
	@ObservationIgnored private var forcedState = WidgetHintState()
	/// Whether the strip has its place in the mosaic.
	private(set) var isRevealed = false
	/// An alert or a removal this session: not a moment for the hint.
	@ObservationIgnored private(set) var hadSetbackThisSession = false
	/// Whether the last lookup found no GrowingUp widget on the Home Screen or in the Today View; a failed lookup did not.
	@ObservationIgnored private var isWidgetAbsent = false
	/// Whether this session's launch is counted already.
	@ObservationIgnored private var countedThisSession = false
	@ObservationIgnored private var lookup: Task<Void, Never>?
	/// The first activation finds the lookup that `init` started on its way.
	@ObservationIgnored private var isFirstActivation = true

	/// - Parameters:
	///   - usage: the days of use, viewer visits and rating requests the rating prompt counts.
	///   - lookUpWidget: whether a GrowingUp Home Screen widget is installed; nil when WidgetKit can't say.
	init(
		store: WidgetHintStore, usage: @escaping () -> ReviewPromptState, mode: WidgetHintMode = .policy,
		policy: WidgetHintPolicy = WidgetHintPolicy(), lookUpWidget: @escaping () async -> Bool?, analytics: AnalyticsGateway,
		now: @escaping () -> Date = Date.init, calendar: Calendar = .autoupdatingCurrent
	) {
		self.store = store
		self.usage = usage
		self.mode = mode
		self.policy = policy
		self.lookUpWidget = lookUpWidget
		self.analytics = analytics
		self.now = now
		self.calendar = calendar
		// Started at once, so on a cold launch the answer is usually in before the people are.
		startLookup()
	}

	/// Whether the mosaic shows the strip with `people` stored now; reordering, which only hides it, is the mosaic's own.
	func offers(people: [Person]) -> Bool {
		isRevealed && policy.allowsPeople(people, now: now(), calendar: calendar)
	}

	/// Gives the strip its place in the mosaic when the rules allow it. Call it only while the mosaic is off screen: as
	/// the people first load, and as the viewer opens over the mosaic.
	func reveal(people: [Person]) {
		guard !isRevealed, !hadSetbackThisSession, !state.isRetired, policy.allowsPeople(people, now: now(), calendar: calendar)
		else { return }
		if mode == .policy {
			guard isWidgetAbsent, policy.allowsLaunch(state, usage: usage(), now: now()) else { return }
		}
		isRevealed = true
		countLaunch()
	}

	/// The strip was tapped: the guide opens, and the hint is gone for good.
	func opened() {
		guard isRevealed else { return }
		retire()
		analytics.track(.widgetHintOpened(shownLaunches: state.shownLaunches))
	}

	/// × closed the strip: it is gone for good.
	func dismissed() {
		guard isRevealed else { return }
		retire()
		analytics.track(.widgetHintDismissed(shownLaunches: state.shownLaunches))
	}

	/// An alert or a removal: the strip leaves for the rest of the session.
	func noteSetback() {
		hadSetbackThisSession = true
		isRevealed = false
	}

	/// The app came to the foreground: a widget added meanwhile, as the guide explains, ends the hint.
	func appBecameActive() {
		if isFirstActivation {
			isFirstActivation = false
			if lookup != nil { return }
		}
		startLookup()
	}

	/// The app left the screen; the next foreground use is a new launch. The strip leaves with it, unseen, and the last
	/// lookup no longer counts: the next launch shows the strip again only once its own lookup has found no widget and the
	/// mosaic is covered once more, so a widget added meanwhile never shows a stale strip and the launch counts only when
	/// the strip really takes its place.
	func appEnteredBackground() {
		hadSetbackThisSession = false
		countedThisSession = false
		isRevealed = false
		isWidgetAbsent = false
	}

	/// Waits for the widget lookup under way, if any.
	func waitForWidgetLookup() async {
		await lookup?.value
	}

	private func startLookup() {
		guard mode == .policy else { return }
		lookup?.cancel()
		let lookUp = lookUpWidget
		lookup = Task { [weak self] in
			let installed = await lookUp()
			guard !Task.isCancelled else { return }
			self?.finishLookup(installed: installed)
		}
	}

	private func finishLookup(installed: Bool?) {
		lookup = nil
		switch installed {
		case true?:
			isWidgetAbsent = false
			if !state.isRetired { retire() }
		case false?:
			// The strip takes its place at the next `reveal(people:)`, while the mosaic is covered.
			isWidgetAbsent = true
		case nil:
			isWidgetAbsent = false
			isRevealed = false
		}
	}

	private func countLaunch() {
		guard !countedThisSession else { return }
		countedThisSession = true
		update { policy.recordingShownLaunch($0) }
		analytics.track(.widgetHintShown(shownLaunches: state.shownLaunches))
	}

	private func retire() {
		isRevealed = false
		update { policy.retiring($0) }
	}

	/// The stored state, or a forced check's own, which starts from nothing and never reaches the store.
	private var state: WidgetHintState {
		get { mode == .forced ? forcedState : store.state }
		set {
			if mode == .forced { forcedState = newValue } else { store.state = newValue }
		}
	}

	private func update(_ change: (WidgetHintState) -> WidgetHintState) {
		state = change(state)
	}
}
