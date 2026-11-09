/// Runs a pass of work a moment after the last request, or at once, one pass at a time: a request while a pass runs gets
/// one more pass after it, so the last request is always followed by a whole pass, as the iCloud backup needs after each
/// change.
@MainActor
final class BackupPassScheduler {
	/// The work; set once its owner exists.
	var pass: () async -> Void = {}
	private let delay: Duration
	private var pending: Task<Void, Never>?
	private var running: Task<Void, Never>?
	private var needsAnotherPass = false

	init(delay: Duration) {
		self.delay = delay
	}

	/// Whether a pass waits or runs.
	var hasWork: Bool { pending != nil || running != nil }

	/// Runs a pass once no other request came for the delay.
	func schedule() {
		pending?.cancel()
		pending = Task { [weak self, delay] in
			try? await Task.sleep(for: delay)
			guard !Task.isCancelled, let self else { return }
			pending = nil
			await runNow()
		}
	}

	/// Drops a pass that waits.
	func cancel() {
		pending?.cancel()
		pending = nil
	}

	/// Runs a pass now, instead of one that waits. A call while a pass runs waits for it and one more pass.
	func runNow() async {
		cancel()
		if let running {
			needsAnotherPass = true
			await running.value
			return
		}
		let passes = Task { [weak self] in
			guard let self else { return }
			repeat {
				needsAnotherPass = false
				await pass()
			} while needsAnotherPass
		}
		running = passes
		await passes.value
		running = nil
		// A call after the last pass decided to stop, but before this point, joined a finished task; it still needs its pass.
		if needsAnotherPass { await runNow() }
	}
}
