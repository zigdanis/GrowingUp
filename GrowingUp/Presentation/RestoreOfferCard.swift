import Core
import SwiftUI

/// Under the empty mosaic's invitation after a reinstall or on a new device: the newest backup of another install in
/// iCloud, with Restore and Not now. The card is the confirmation, so Restore loads and restores that backup at once, and
/// the alert then says what it added; Not now hides the offer for good, and Settings still lists every backup.
struct RestoreOfferCard: View {
	let presenter: BackupPresenter
	let offer: BackupCandidate
	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	private var isWorking: Bool { presenter.loadingCandidateID == offer.id || presenter.isRestoring }

	var body: some View {
		VStack(spacing: 16) {
			Image(systemName: "icloud.and.arrow.down")
				.font(.title.weight(.semibold))
				.foregroundStyle(.tint)
				.accessibilityHidden(true)
			VStack(spacing: 6) {
				Text("Restore from iCloud?")
					.font(.headline)
					.accessibilityAddTraits(.isHeader)
				Group {
					Text("Your backup from \(offer.createdAt.formatted(date: .long, time: .omitted)).")
					Text("People: \(offer.peopleCount)")
				}
				.font(.subheadline)
				.foregroundStyle(.secondary)
			}
			.fixedSize(horizontal: false, vertical: true)
			VStack(spacing: 4) {
				Button {
					Task { await presenter.restoreOffered(offer) }
				} label: {
					HStack(spacing: 8) {
						if isWorking { ProgressView() }
						Text(isWorking ? "Restoring…" : "Restore")
					}
					.font(.body.weight(.semibold))
					.frame(maxWidth: .infinity)
				}
				.modifier(GlassCapsuleButtonChrome(prominent: true))
				.controlSize(.large)
				.disabled(isWorking || presenter.isBusy)
				.accessibilityIdentifier("backup.offer.restore")
				Button {
					withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { presenter.iCloud?.dismissRestoreOffer() }
				} label: {
					Text("Not now")
						.font(.subheadline)
						.frame(maxWidth: .infinity, minHeight: 44)
						.contentShape(.rect)
				}
				.buttonStyle(.plain)
				.foregroundStyle(.tint)
				.disabled(isWorking)
				.accessibilityIdentifier("backup.offer.dismiss")
			}
		}
		.multilineTextAlignment(.center)
		.padding(.horizontal, 20)
		.padding(.top, 20)
		.padding(.bottom, 10)
		.frame(maxWidth: .infinity)
		.background { MosaicGlass(shape: .rect(cornerRadius: MosaicTile.cornerRadius, style: .continuous)) }
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier("backup.offer")
	}
}
