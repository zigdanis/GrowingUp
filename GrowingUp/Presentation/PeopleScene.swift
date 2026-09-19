import SwiftUI

struct PeopleScene: View {
	@Bindable var presenter: PeoplePresenter

	var body: some View {
		Group {
			if presenter.isLoading {
				ProgressView()
			} else {
				TabView(selection: $presenter.selectedID) {
					ForEach(presenter.persons, id: \.id) { person in
						PersonOverviewScene(person: person, onEdit: { presenter.edit(person) })
							.tag(Optional(person.id))
					}
					if presenter.canAdd {
						EmptyPersonScene(onAdd: presenter.add).tag(UUID?.none)
					}
				}
				.tabViewStyle(.page(indexDisplayMode: .always))
			}
		}
		.task { await presenter.load() }
		.onOpenURL(perform: presenter.open)
		.sheet(item: $presenter.editor) { editor in PersonEditorScene(presenter: editor) }
		.sceneError($presenter.error)
	}
}
