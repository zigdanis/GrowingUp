import Core
import StoreKit
import SwiftUI

/// The home screen: the mosaic of people over their ambient glow, with the floating "Add" button; a tile zooms its person
/// open in the full-screen viewer, which swipes down back into the tile. "Add" zooms open a new person's empty edit mode
/// the same way; while a long press reorders the mosaic, "Done" takes the button's place. After the last tile, the mosaic
/// may offer the Home Screen widget hint, which opens the widget guide.
struct PeopleScene: View {
	@Bindable var presenter: PeoplePresenter
	let preferredColorScheme: ColorScheme?
	@State private var pictures: MosaicPicturesPresenter
	/// Earlier data store recovery set aside, which the corner capsule opens.
	@State private var preserved: PreservedDataPresenter
	@State private var showsPreservedData = false
	@Namespace private var zoom
	@State private var isShowingWidgetGuide = false
	/// The pinned people as the widget shows them, for the widget hint and its guide; nil while neither needs them.
	@State private var widgetPreview: AgeEntry?
	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion
	@Environment(\.haptics)
	private var haptics
	@Environment(\.scenePhase)
	private var scenePhase
	@Environment(\.requestReview)
	private var requestReview

	init(presenter: PeoplePresenter, preferredColorScheme: ColorScheme?) {
		_presenter = Bindable(presenter)
		self.preferredColorScheme = preferredColorScheme
		_pictures = State(initialValue: MosaicPicturesPresenter(loadThumbnail: presenter.configurator.loadThumbnail))
		_preserved = State(
			initialValue: PreservedDataPresenter(gateway: presenter.configurator.preservedStores, analytics: presenter.configurator.analytics))
	}

	var body: some View {
		GeometryReader { geometry in
			let window = windowSize(of: geometry)
			let layout = PersonPageLayout(window: window)
			let trailingPane = TrailingPaneOnLandscape(
				layout: layout, spansFold: layout.spansFold(idiom: idiom), window: window, trailingInset: geometry.safeAreaInsets.trailing)
			home(layout: layout, trailingPane: trailingPane)
				.overlay { MosaicEdgeScrims(safeAreaInsets: geometry.safeAreaInsets) }
				.safeAreaInset(edge: .top, spacing: 8) {
					if preserved.newest != nil {
						HomeCornerButton { showsPreservedData = true }
							.frame(maxWidth: .infinity, alignment: .trailing)
							.padding(.horizontal, 16)
							.transition(.opacity)
					}
				}
				// The list's last row always scrolls clear of the button.
				.safeAreaInset(edge: .bottom, spacing: 12) {
					if presenter.isReordering {
						floating(
							FloatingCapsuleButton(title: "Done", systemImage: "checkmark", action: finishReordering)
								.accessibilityIdentifier("people.reorder.done"),
							trailingPane: trailingPane)
					} else if case .unavailable(let isRetrying) = presenter.library.state {
						floating(
							FloatingCapsuleButton(title: "Try Again", systemImage: "arrow.clockwise", action: retry)
								.disabled(isRetrying)
								.accessibilityIdentifier("people.retry"),
							trailingPane: trailingPane)
					} else if presenter.library.state == .loaded, presenter.canAdd {
						floating(
							// A new person's edit mode grows out of the button, which no selected person names.
							FloatingCapsuleButton(
								title: "Add person", systemImage: "plus", action: add, zoomSource: (UUID?.none, zoom)
							)
							.keyboardShortcut("n", modifiers: .command)
							.accessibilityIdentifier("person.add"),
							trailingPane: trailingPane)
					}
				}
		}
		// The mosaic has no text input; beside another app in Split View, its keyboard must not move it.
		.ignoresSafeArea(.keyboard)
		.background { AmbientBackground(seeds: pictures.ambientSeeds(for: presenter.persons)) }
		.task {
			await presenter.loadWithWidgetHint()
			// The load may have just set a store aside, by this process or the widget's; only now is it there to find.
			await preserved.refresh()
		}
		.task(id: presenter.persons) { await pictures.load(presenter.persons) }
		// Back in the app, whatever could not be read before gets another try, such as after the device was unlocked.
		.task(id: scenePhase) {
			guard scenePhase == .active else { return }
			await presenter.load()
			// A load that only now succeeded may have set a store aside, and the widget may have while the app was away.
			await preserved.refresh()
			await pictures.retryFailedPictures()
		}
		.onOpenURL(perform: presenter.open)
		.preferredColorScheme(preferredColorScheme)
		.fullScreenCover(isPresented: $presenter.isViewing, onDismiss: coverDidClose) {
			PersonViewer(presenter: presenter)
				.navigationTransition(.zoom(sourceID: presenter.selectedID, in: zoom))
				// The viewer lies on photos, so it stays dark whatever the mosaic's theme.
				.preferredColorScheme(.dark)
		}
		// An archive the closed sheet can no longer share is removed, even one still being written.
		.sheet(isPresented: $showsPreservedData, onDismiss: preserved.abandonExport) {
			PreservedDataSheet(presenter: preserved)
		}
		// A widget link that opens a person takes the screen over.
		.onChange(of: presenter.isViewing) { _, isViewing in
			if isViewing { showsPreservedData = false }
		}
		.sheet(isPresented: $isShowingWidgetGuide) {
			WidgetGuideSheet(entry: widgetPreview, now: presenter.configurator.now)
		}
		.sceneError($presenter.error)
		.onChange(of: scenePhase, initial: true) { _, phase in
			let prompter = presenter.configurator.reviewPrompter
			let hinter = presenter.configurator.widgetHinter
			switch phase {
			// The prompter counts the day of use first, which the hint's rules read.
			case .active:
				prompter?.appBecameActive()
				hinter?.appBecameActive()
			case .background:
				prompter?.appEnteredBackground()
				hinter?.appEnteredBackground()
			default: prompter?.appResignedActive()
			}
		}
		// The widget hint takes its place while the viewer covers the mosaic, once the cover has grown over it.
		.task(id: presenter.isViewing) {
			guard presenter.isViewing, presenter.configurator.widgetHinter != nil else { return }
			do { try await Task.sleep(for: .seconds(0.6)) } catch { return }
			if presenter.isViewing { presenter.revealWidgetHint() }
		}
		.task(id: widgetPreviewPeople) {
			// Once neither the hint nor its guide shows, the preview's pictures are let go.
			guard widgetPreviewPeople != nil else {
				widgetPreview = nil
				return
			}
			let entry = await presenter.widgetPreviewEntry()
			// A load the hint closing or the pinned people changing replaced must not bring back its pictures.
			guard !Task.isCancelled else { return }
			widgetPreview = entry
		}
		// The viewer has zoomed back into the mosaic; after a short pause there, as Apple advises, iOS may show its rating sheet.
		.task(id: presenter.configurator.reviewPrompter?.pendingRequest) {
			guard let request = presenter.configurator.reviewPrompter?.pendingRequest else { return }
			do { try await Task.sleep(for: .seconds(2)) } catch { return }
			if presenter.takeReviewRequest(request) { requestReview() }
		}
	}

	@ViewBuilder
	private func home(layout: PersonPageLayout, trailingPane: TrailingPaneOnLandscape) -> some View {
		if presenter.library.state == .loading {
			ProgressView()
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		} else if presenter.library.state != .loaded {
			PeopleNotice.unavailable
				.modifier(trailingPane)
				.frame(maxHeight: .infinity)
				.transition(.opacity)
		} else if presenter.persons.isEmpty {
			PeopleNotice.invitation
				.modifier(trailingPane)
				.frame(maxHeight: .infinity)
				.transition(.opacity)
		} else {
			PeopleMosaic(
				persons: presenter.persons, pictures: pictures, selectedID: presenter.selectedID,
				evenColumns: layout == .landscape && layout.spansFold(idiom: idiom), tileWidths: MosaicGridLayout.tileWidths(idiom: idiom),
				fillsWindow: idiom == .pad,
				isReordering: presenter.isReordering, reservesHint: presenter.reservesWidgetHint,
				hint: presenter.reservesWidgetHint ? widgetHint : nil, zoom: zoom, now: presenter.configurator.now, onOpen: openPerson,
				onStartReordering: presenter.startReordering, onFinishReordering: finishReordering, onMove: presenter.move,
				onShift: presenter.shift, onSaveOrder: presenter.saveOrder
			)
			.transition(.opacity)
		}
	}

	private var idiom: UIUserInterfaceIdiom { UIDevice.current.userInterfaceIdiom }

	/// The widget hint in `placement`.
	private func widgetHint(_ placement: WidgetHintPlacement) -> WidgetHintStrip {
		WidgetHintStrip(placement: placement, entry: widgetPreview, onOpen: openWidgetGuide, onDismiss: dismissWidgetHint)
	}

	/// The people the widget preview shows while the hint or its guide needs it, so a change to them redraws it.
	private var widgetPreviewPeople: [Person]? {
		presenter.reservesWidgetHint || isShowingWidgetGuide ? presenter.persons.filter(\.isOnWidget) : nil
	}

	/// A tap on the hint opens the guide, as the hint fades out for good.
	private func openWidgetGuide() {
		let opens = withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { presenter.openWidgetHint() }
		guard opens else { return }
		haptics.play(.tileOpened)
		isShowingWidgetGuide = true
	}

	/// × fades the hint out, and the tiles close up behind it.
	private func dismissWidgetHint() {
		withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { presenter.dismissWidgetHint() }
	}

	/// Opens the person with `id` in the viewer, with a light tap when their tile did open them.
	private func openPerson(_ id: UUID) {
		presenter.view(id)
		if presenter.isViewing { haptics.play(.tileOpened) }
	}

	private func add() {
		presenter.add()
		if presenter.isAddingPerson { haptics.play(.addPerson) }
	}

	private func retry() {
		Task {
			await presenter.load()
			await preserved.refresh()
		}
	}

	private func finishReordering() {
		guard presenter.isReordering else { return }
		haptics.play(.reorderFinished)
		presenter.finishReordering()
	}

	/// The floating capsule spread across the mosaic, in the trailing pane of a landscape window that may span a fold,
	/// above the home indicator.
	private func floating(_ button: some View, trailingPane: TrailingPaneOnLandscape) -> some View {
		button
			.frame(maxWidth: .infinity)
			.modifier(trailingPane)
			.padding(.bottom, 8)
	}

	/// Once the cover has zoomed back into the mosaic, a removed person's tile leaves and its neighbours close the gap, or
	/// the invitation takes the place of the last one.
	private func coverDidClose() {
		withAnimation(reduceMotion ? nil : .snappy(duration: 0.35)) { presenter.coverDidClose() }
		// The mosaic shows again, with the strip if it took its place under the viewer: now the launch counts.
		presenter.noteWidgetHintSeen()
	}

	/// The whole window, safe areas included, whose shape picks the layout like the viewer's pages.
	private func windowSize(of geometry: GeometryProxy) -> CGSize {
		let insets = geometry.safeAreaInsets
		return CGSize(
			width: geometry.size.width + insets.leading + insets.trailing, height: geometry.size.height + insets.top + insets.bottom)
	}
}
