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
					ZStack(alignment: .bottom) {
						TabView(selection: $presenter.selectedID) {
							ForEach(presenter.persons, id: \.id) { person in
								PersonOverviewScene(
									person: person, isSelected: presenter.selectedID == person.id, configurator: presenter.configurator,
									safeAreaInsets: geometry.safeAreaInsets,
									onEdit: { presenter.edit(person) },
									onCardHeightChange: { cardHeights[person.id] = $0 }
								)
								.tag(Optional(person.id))
							}
							if presenter.canAdd {
								EmptyPersonScene(onAdd: presenter.add).tag(UUID?.none)
							}
						}
						.tabViewStyle(.page(indexDisplayMode: .never))
						.ignoresSafeArea(.container)
						if !presenter.persons.isEmpty {
							PeopleAvatarStrip(
								persons: presenter.persons, selectedID: presenter.selectedID, canAdd: presenter.canAdd, thumbnails: thumbnails,
								onSelect: { id in withAnimation { presenter.select(id) } }
							)
							.padding(.bottom, stripBottomPadding)
							.animation(cardHeights.isEmpty ? nil : .snappy, value: stripBottomPadding)
						}
					}
				}
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

	/// Keeps the strip above the shown person's card; the add page has no card, so the strip stays where it was.
	private var stripBottomPadding: CGFloat {
		let cardHeight = presenter.selectedID.flatMap { cardHeights[$0] } ?? cardHeights.values.max() ?? 0
		return cardHeight + 8
	}
}
