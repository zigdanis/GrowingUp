/// One-shot gate guarding a continuation against repeated PhotoKit callbacks.
@MainActor
final class ContinuationGate {
	private var finished = false

	func finish(when shouldFinish: Bool) -> Bool {
		guard shouldFinish, !finished else { return false }
		finished = true
		return true
	}
}
