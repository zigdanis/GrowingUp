import SwiftUI

struct PeopleScene: View {
	@Bindable var presenter: PeoplePresenter
	let preferredColorScheme: ColorScheme?
	@State private var thumbnails: AvatarThumbnailsPresenter
	/// The height of each person's bottom card, so the avatar strip can float just above the card on screen.
	@State private var cardHeights: [UUID: CGFloat] = [:]

	init(presenter: PeoplePresenter, preferredColorScheme: ColorScheme?) {
		_presenter = Bindable(presenter)
		self.preferredColorScheme = preferredColorScheme
		_thumbnails = State(initialValue: AvatarThumbnailsPresenter(loadImage: presenter.configurator.loadImage))
	}

	var body: some View {
		Group {
			if presenter.isLoading {
				ProgressView()
			} else {
				GeometryReader { geometry in
					let window = windowSize(of: geometry)
					let layout = PersonPageLayout(window: window)
					ZStack(alignment: .bottom) {
						// A paging scroll view rather than a page-style TabView, whose UIKit pager insets its pages by a
						// horizontal safe area (the iPhone Duo's side status bar) and so snaps them off the window.
						ScrollView(.horizontal) {
							LazyHStack(spacing: 0) {
								ForEach(presenter.persons, id: \.id) { person in
									PersonOverviewScene(
										person: person, isSelected: presenter.selectedID == person.id, configurator: presenter.configurator,
										safeAreaInsets: geometry.safeAreaInsets, layout: layout, pageSize: window,
										onEdit: { presenter.edit(person) },
										onCardHeightChange: { cardHeights[person.id] = $0 }
									)
									.containerRelativeFrame([.horizontal, .vertical])
									.id(PeoplePageID.person(person.id))
								}
								if presenter.canAdd {
									EmptyPersonScene(onAdd: presenter.add, stripClearance: stripClearance)
										// The pager ignores the safe area, so the invitation keeps clear of the status bar itself.
										.safeAreaPadding(geometry.safeAreaInsets)
										.containerRelativeFrame([.horizontal, .vertical])
										.id(PeoplePageID.add)
								}
							}
							.scrollTargetLayout()
						}
						.scrollTargetBehavior(.paging)
						.scrollIndicators(.hidden)
						.scrollPosition(id: page)
						.ignoresSafeArea()
						if !presenter.persons.isEmpty {
							Group {
								switch layout {
								case .phone:
									avatarStrip
								case .widePortrait:
									avatarStrip.frame(maxWidth: layout.columnWidth)
								case .landscape:
									// Centered in the trailing pane, which starts halfway across the window.
									avatarStrip
										.frame(maxWidth: layout.columnWidth)
										.frame(width: max(0, window.width / 2 - geometry.safeAreaInsets.trailing))
										.frame(maxWidth: .infinity, alignment: .trailing)
								}
							}
							.padding(.bottom, stripBottomPadding)
							.animation(cardHeights.isEmpty ? nil : .snappy, value: stripBottomPadding)
						}
					}
				}
				// The pages have no text input; beside another app in Split View, its keyboard must not move them.
				.ignoresSafeArea(.keyboard)
			}
		}
		.task { await presenter.load() }
		.task(id: presenter.persons) { await thumbnails.load(presenter.persons) }
		.onOpenURL(perform: presenter.open)
		.preferredColorScheme(presenter.selectedID == nil ? preferredColorScheme : .dark)
		.sheet(item: $presenter.editor) { editor in
			PersonEditorScene(presenter: editor).preferredColorScheme(preferredColorScheme)
		}
		.sceneError($presenter.error)
	}

	/// The pager's position as the presenter's selection; the pager reports nil only between pages, which keeps the last one.
	private var page: Binding<PeoplePageID?> {
		Binding(
			get: { PeoplePageID(selectedID: presenter.selectedID) },
			set: { page in
				guard let page else { return }
				presenter.select(page.selectedID)
			})
	}

	private var avatarStrip: some View {
		PeopleAvatarStrip(
			persons: presenter.persons, selectedID: presenter.selectedID, canAdd: presenter.canAdd, thumbnails: thumbnails,
			onSelect: { id in withAnimation { presenter.select(id) } }
		)
	}

	/// The whole window: the pages draw under the safe areas, so their layout is chosen from the full shape.
	private func windowSize(of geometry: GeometryProxy) -> CGSize {
		let insets = geometry.safeAreaInsets
		return CGSize(
			width: geometry.size.width + insets.leading + insets.trailing, height: geometry.size.height + insets.top + insets.bottom)
	}

	/// Keeps the strip above the shown person's card; the add page has no card, so the strip stays where it was.
	private var stripBottomPadding: CGFloat {
		let cardHeight = presenter.selectedID.flatMap { cardHeights[$0] } ?? cardHeights.values.max() ?? 0
		return cardHeight + 8
	}

	/// How high the strip's top sits above the bottom of the pages, so the add page's invitation stays above it;
	/// with nobody added yet there is no strip to clear.
	private var stripClearance: CGFloat {
		presenter.persons.isEmpty ? 0 : stripBottomPadding + PeopleAvatarStrip.height
	}
}
