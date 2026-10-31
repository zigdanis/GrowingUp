import Core
import SwiftUI

/// The full-screen cover over the mosaic: the viewer, one person per page, swiping sideways through people in mosaic
/// order, or a new person's empty edit mode, grown out of the "Add" button.
///
/// Swiping down belongs to the zoom transition that closes the viewer back into the shown person's tile. A tap turns
/// the shown page into its in-place edit mode, which locks both swipes until Cancel or Done.
struct PersonViewer: View {
	let presenter: PeoplePresenter
	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	var body: some View {
		let editMode = presenter.editMode
		GeometryReader { geometry in
			let window = windowSize(of: geometry)
			let layout = PersonPageLayout(window: window)
			if presenter.isAddingPerson {
				// A new person has no page among the people yet: their edit mode lies on the app's glow, which also shrinks
				// back into the button after Cancel.
				AmbientBackground(seeds: [])
					.transition(.opacity)
			} else {
				pager(window: window, layout: layout, safeAreaInsets: geometry.safeAreaInsets, isEditing: editMode != nil)
					.transition(.opacity)
			}
			if let editMode {
				PersonEditModeScene(mode: editMode, layout: layout, window: window, safeAreaInsets: geometry.safeAreaInsets)
					// A session that replaces the open one, such as from a widget link, starts the scene afresh and loads itself.
					.id(ObjectIdentifier(editMode))
					.transition(.opacity)
			}
		}
		.animation(.easeInOut(duration: 0.25), value: editMode != nil)
		.animation(.easeInOut(duration: 0.25), value: presenter.isAddingPerson)
		// The edit mode's name field sits in the top third, clear of the keyboard, so the keyboard never moves the photo;
		// nor does another app's keyboard beside the viewer in Split View.
		.ignoresSafeArea(.keyboard)
		.background(.black)
		// Locks the zoom transition's swipe down while editing. Verified on iOS 18.6 and 27.0 with a drag-down UI test
		// (NavigationTests): with this modifier the cover stays, without it the same drag closes the viewer; after Cancel or
		// Done the swipe zooms back into the tile again. No UIKit hook into the presentation controller is needed.
		.interactiveDismissDisabled(editMode != nil)
	}

	private func pager(window: CGSize, layout: PersonPageLayout, safeAreaInsets: EdgeInsets, isEditing: Bool) -> some View {
		// A paging scroll view rather than a page-style TabView, whose UIKit pager insets its pages by a
		// horizontal safe area (the iPhone Duo's side status bar) and so snaps them off the window.
		ScrollViewReader { proxy in
			ScrollView(.horizontal) {
				LazyHStack(spacing: 0) {
					ForEach(presenter.persons, id: \.id) { person in
						PersonOverviewScene(
							person: person, isSelected: presenter.selectedID == person.id, isEditing: isEditing, configurator: presenter.configurator,
							safeAreaInsets: safeAreaInsets, layout: layout, pageSize: window,
							onEdit: { presenter.edit(person) },
							onClose: presenter.closeViewer,
							onNext: pageAction(from: person, by: 1),
							onPrevious: pageAction(from: person, by: -1)
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
			.scrollDisabled(isEditing)
			.accessibilityHidden(isEditing)
			// On the pager alone: on the whole viewer it would replace the edit mode's own identifiers.
			.accessibilityIdentifier("person.viewer")
			.ignoresSafeArea()
			// A freshly presented pager starts on its first page whatever its position says, so it moves to the tapped person
			// before the zoom reveals it.
			.onAppear { proxy.scrollTo(presenter.selectedID) }
		}
	}

	/// Pages from `person` to their neighbour `offset` places along, as VoiceOver's "Next person" and "Previous person"
	/// do; nil past either end.
	private func pageAction(from person: Person, by offset: Int) -> (() -> Void)? {
		guard let neighbour = presenter.neighbour(of: person.id, by: offset) else { return nil }
		return {
			withAnimation(reduceMotion ? nil : .default) { presenter.select(neighbour) }
		}
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
