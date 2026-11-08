import SwiftUI

/// "GrowingUp widgets": how to add the widget to the Home Screen or the Today View, in four steps named with the
/// system's own button titles, under a picture that acts out the highlighted step.
///
/// The steps light up one after another every few seconds and a tap plays any of them; with Reduce Motion nothing moves
/// and each step shows its own still picture.
struct WidgetGuideSheet: View {
	/// The user's pinned people, which the pictures' widget shows; nil while they load.
	let entry: AgeEntry?
	let now: () -> Date
	@State private var playback = WidgetGuidePlayback()
	@State private var detent = PresentationDetent.large
	/// Restarts the beat timer, as a tap on a step or another tab does.
	@State private var restarts = 0
	@Environment(\.dismiss)
	private var dismiss
	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			header
			Picker("Where", selection: tab) {
				Text("Home Screen").tag(WidgetGuideTab.homeScreen)
				Text("Today View").tag(WidgetGuideTab.todayView)
			}
			.pickerStyle(.segmented)
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					WidgetGuideIllustration(frame: playback.frame, entry: entry, date: now(), isAnimated: !reduceMotion)
						.frame(maxWidth: 420)
						.frame(maxWidth: .infinity)
					VStack(alignment: .leading, spacing: 11) {
						ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
							WidgetGuideStepRow(number: index + 1, title: title, isHighlighted: playback.step == index) {
								playback.jump(to: index)
								restarts += 1
							}
						}
					}
				}
				.padding(.bottom, 16)
			}
			.scrollBounceBehavior(.basedOnSize)
		}
		.padding(.horizontal, 20)
		.padding(.top, 20)
		.safeAreaInset(edge: .bottom) {
			Button {
				dismiss()
			} label: {
				Text("Done")
					.font(.headline)
					.frame(maxWidth: .infinity, minHeight: 34)
			}
			.modifier(GlassCapsuleButtonChrome(prominent: true))
			.controlSize(.large)
			.padding(.horizontal, 20)
			.padding(.bottom, 8)
			.accessibilityIdentifier("widgetGuide.done")
		}
		.task(id: WidgetGuideTimerKey(tab: playback.tab, restarts: restarts, isAnimated: !reduceMotion)) {
			guard !reduceMotion else { return }
			while !Task.isCancelled {
				do { try await Task.sleep(for: .seconds(WidgetGuidePlayback.beatDuration)) } catch { return }
				playback.advance()
			}
		}
		.presentationDetents([.medium, .large], selection: $detent)
		.presentationDragIndicator(.visible)
	}

	private var header: some View {
		HStack(alignment: .firstTextBaseline) {
			Text("GrowingUp widgets")
				.font(.title2.bold())
				.accessibilityAddTraits(.isHeader)
			Spacer(minLength: 12)
			Button {
				dismiss()
			} label: {
				Image(systemName: "xmark")
					.font(.body.weight(.semibold))
			}
			.buttonStyle(.bordered)
			.buttonBorderShape(.circle)
			.accessibilityLabel(Text("Close"))
			.accessibilityIdentifier("widgetGuide.close")
		}
	}

	private var tab: Binding<WidgetGuideTab> {
		Binding(
			get: { playback.tab },
			set: { tab in
				playback.show(tab)
				restarts += 1
			})
	}

	private var steps: [LocalizedStringKey] {
		switch playback.tab {
		case .homeScreen:
			["Touch and hold an empty spot on your Home Screen", "Tap Edit, then Add Widget", "Find GrowingUp", "Pick a size and tap Add Widget"]
		case .todayView:
			[
				"On your first Home Screen page, swipe right", "Touch and hold an empty spot, tap Edit, then Add Widget", "Find GrowingUp",
				"Pick a size and tap Add Widget"
			]
		}
	}
}
