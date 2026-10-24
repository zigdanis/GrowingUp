import Core
import SwiftUI

/// The full-screen viewer over the mosaic: one person per page, swiping sideways through people in mosaic order.
///
/// Swiping down belongs to the zoom transition that closes the viewer back into the shown person's tile.
struct PersonViewer: View {
	let presenter: PeoplePresenter

	var body: some View {
		GeometryReader { geometry in
			let window = windowSize(of: geometry)
			let layout = PersonPageLayout(window: window)
			// A paging scroll view rather than a page-style TabView, whose UIKit pager insets its pages by a
			// horizontal safe area (the iPhone Duo's side status bar) and so snaps them off the window.
			ScrollViewReader { proxy in
				ScrollView(.horizontal) {
					LazyHStack(spacing: 0) {
						ForEach(presenter.persons, id: \.id) { person in
							PersonOverviewScene(
								person: person, isSelected: presenter.selectedID == person.id, configurator: presenter.configurator,
								safeAreaInsets: geometry.safeAreaInsets, layout: layout, pageSize: window,
								onEdit: { presenter.edit(person) },
								onClose: presenter.closeViewer
							)
							.containerRelativeFrame([.horizontal, .vertical])
							.id(person.id)
						}
					}
					.scrollTargetLayout()
				}
				.scrollTargetBehavior(.paging)
				.scrollIndicators(.hidden)
				.scrollPosition(id: page)
				.ignoresSafeArea()
				// A freshly presented pager starts on its first page whatever its position says, so it moves to the tapped person
				// before the zoom reveals it.
				.onAppear { proxy.scrollTo(presenter.selectedID) }
			}
		}
		// The pages have no text input; beside another app in Split View, its keyboard must not move them.
		.ignoresSafeArea(.keyboard)
		.background(.black)
		.accessibilityIdentifier("person.viewer")
	}

	/// The pager's position as the presenter's selection; the pager reports nil only between pages, which keeps the last one.
	private var page: Binding<UUID?> {
		Binding(
			get: { presenter.selectedID },
			set: { id in
				guard let id else { return }
				presenter.select(id)
			})
	}

	/// The whole window: the pages draw under the safe areas, so their layout is chosen from the full shape.
	private func windowSize(of geometry: GeometryProxy) -> CGSize {
		let insets = geometry.safeAreaInsets
		return CGSize(
			width: geometry.size.width + insets.leading + insets.trailing, height: geometry.size.height + insets.top + insets.bottom)
	}
}
