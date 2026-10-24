import Core
import SwiftUI

/// The full-screen viewer over the mosaic: one person per page, swiping sideways through people in mosaic order.
///
/// Swiping down belongs to the zoom transition that closes the viewer back into the shown person's tile. A tap turns
/// the shown page into its in-place edit mode, which locks both swipes until Cancel or Done.
struct PersonViewer: View {
	let presenter: PeoplePresenter

	var body: some View {
		let editMode = presenter.editMode
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
				// Edit mode gives every gesture to the photo's framing, so the pager stays on the edited person.
				.scrollDisabled(editMode != nil)
				.accessibilityHidden(editMode != nil)
				.ignoresSafeArea()
				// A freshly presented pager starts on its first page whatever its position says, so it moves to the tapped person
				// before the zoom reveals it.
				.onAppear { proxy.scrollTo(presenter.selectedID) }
			}
			if let editMode {
				PersonEditModeScene(mode: editMode, layout: layout, window: window, safeAreaInsets: geometry.safeAreaInsets)
					.transition(.opacity)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: editMode != nil)
		// The edit mode's name field sits in the top third, clear of the keyboard, so the keyboard never moves the photo;
		// nor does another app's keyboard beside the viewer in Split View.
		.ignoresSafeArea(.keyboard)
		.background(.black)
		.accessibilityIdentifier("person.viewer")
		// Locks the zoom transition's swipe down while editing. Verified on iOS 18.6 and 27.0 with a drag-down UI test
		// (NavigationTests): with this modifier the cover stays, without it the same drag closes the viewer; after Cancel or
		// Done the swipe zooms back into the tile again. No UIKit hook into the presentation controller is needed.
		.interactiveDismissDisabled(editMode != nil)
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
