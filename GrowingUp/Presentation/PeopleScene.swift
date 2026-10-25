import SwiftUI

/// The home screen: the mosaic of people over their ambient glow, with the floating "Add" button; a tile zooms its person
/// open in the full-screen viewer, which swipes down back into the tile. "Add" opens the editor sheet; while a long press
/// reorders the mosaic, "Done" takes the button's place.
struct PeopleScene: View {
	@Bindable var presenter: PeoplePresenter
	let preferredColorScheme: ColorScheme?
	@State private var pictures: MosaicPicturesPresenter
	@Namespace private var zoom

	init(presenter: PeoplePresenter, preferredColorScheme: ColorScheme?) {
		_presenter = Bindable(presenter)
		self.preferredColorScheme = preferredColorScheme
		_pictures = State(initialValue: MosaicPicturesPresenter(loadThumbnail: presenter.configurator.loadThumbnail))
	}

	var body: some View {
		GeometryReader { geometry in
			let window = windowSize(of: geometry)
			let layout = PersonPageLayout(window: window)
			let trailingPane = TrailingPaneOnLandscape(layout: layout, window: window, trailingInset: geometry.safeAreaInsets.trailing)
			home(layout: layout, trailingPane: trailingPane)
				.overlay { MosaicEdgeScrims(safeAreaInsets: geometry.safeAreaInsets) }
				// The list's last row always scrolls clear of the button.
				.safeAreaInset(edge: .bottom, spacing: 12) {
					if presenter.isReordering {
						floatingButton(
							"Done", systemImage: "checkmark", identifier: "people.reorder.done", trailingPane: trailingPane,
							action: presenter.finishReordering)
					} else if !presenter.isLoading, presenter.canAdd {
						floatingButton("Add person", systemImage: "plus", identifier: "person.add", trailingPane: trailingPane, action: presenter.add)
					}
				}
		}
		// The mosaic has no text input; beside another app in Split View, its keyboard must not move it.
		.ignoresSafeArea(.keyboard)
		.background { AmbientBackground(seeds: pictures.ambientSeeds(for: presenter.persons)) }
		.task { await presenter.load() }
		.task(id: presenter.persons) { await pictures.load(presenter.persons) }
		.onOpenURL(perform: presenter.open)
		.preferredColorScheme(preferredColorScheme)
		.fullScreenCover(isPresented: $presenter.isViewing) {
			PersonViewer(presenter: presenter)
				.navigationTransition(.zoom(sourceID: presenter.selectedID, in: zoom))
				// The viewer lies on photos, so it stays dark whatever the mosaic's theme.
				.preferredColorScheme(.dark)
				.sheet(item: editor(whileViewing: true), content: editorScene)
		}
		.sheet(item: editor(whileViewing: false), content: editorScene)
		.sceneError($presenter.error)
	}

	@ViewBuilder
	private func home(layout: PersonPageLayout, trailingPane: TrailingPaneOnLandscape) -> some View {
		if presenter.isLoading {
			ProgressView()
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		} else if presenter.persons.isEmpty {
			PeopleInvitation()
				.frame(maxWidth: .infinity)
				.modifier(trailingPane)
				.frame(maxHeight: .infinity)
		} else {
			PeopleMosaic(
				persons: presenter.persons, pictures: pictures, selectedID: presenter.selectedID, evenColumns: layout == .landscape,
				isReordering: presenter.isReordering, zoom: zoom, now: presenter.configurator.now, onOpen: presenter.view,
				onStartReordering: presenter.startReordering, onFinishReordering: presenter.finishReordering, onMove: presenter.move,
				onSaveOrder: presenter.saveOrder)
		}
	}

	/// The floating capsule spread across the mosaic, in the trailing pane of a landscape window, above the home indicator.
	private func floatingButton(
		_ title: LocalizedStringKey, systemImage: String, identifier: String, trailingPane: TrailingPaneOnLandscape,
		action: @escaping () -> Void
	) -> some View {
		FloatingCapsuleButton(title: title, systemImage: systemImage, action: action)
			.accessibilityIdentifier(identifier)
			.frame(maxWidth: .infinity)
			.modifier(trailingPane)
			.padding(.bottom, 8)
	}

	/// The editor sheet's binding for one presenter of the sheet: the viewer while it is shown, otherwise the mosaic.
	/// Only a new person opens the sheet; an existing one is edited in place in the viewer.
	private func editor(whileViewing: Bool) -> Binding<PersonEditorPresenter?> {
		Binding(
			get: { presenter.isViewing == whileViewing ? presenter.sheetEditor : nil },
			set: { editor in
				guard presenter.isViewing == whileViewing, editor == nil else { return }
				presenter.cancelEditing(presenter.sheetEditor)
			})
	}

	private func editorScene(_ editor: PersonEditorPresenter) -> some View {
		PersonEditorScene(presenter: editor).preferredColorScheme(preferredColorScheme)
	}

	/// The whole window, safe areas included, whose shape picks the layout like the viewer's pages.
	private func windowSize(of geometry: GeometryProxy) -> CGSize {
		let insets = geometry.safeAreaInsets
		return CGSize(
			width: geometry.size.width + insets.leading + insets.trailing, height: geometry.size.height + insets.top + insets.bottom)
	}
}
