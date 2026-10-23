import Core
import SwiftUI

/// The row of avatars that switches between people pages; the trailing "+" shows the add page.
///
/// It scrolls once there are more people than fit across the screen, keeping the selected avatar in view.
struct PeopleAvatarStrip: View {
	let persons: [Person]
	let selectedID: UUID?
	let canAdd: Bool
	let thumbnails: AvatarThumbnailsPresenter
	let onSelect: (UUID?) -> Void
	/// The strip's height, so the pages behind it can keep their content clear of it.
	static let height: CGFloat = 44

	var body: some View {
		ViewThatFits(in: .horizontal) {
			avatars
			ScrollViewReader { proxy in
				ScrollView(.horizontal, showsIndicators: false) {
					avatars
				}
				// A horizontal scroll view would otherwise grow vertically inside the bottom-aligned overlay.
				.frame(height: Self.height)
				.onAppear { proxy.scrollTo(selectedID, anchor: .center) }
				.onChange(of: selectedID) { _, id in
					withAnimation { proxy.scrollTo(id, anchor: .center) }
				}
			}
		}
	}

	private var avatars: some View {
		HStack(spacing: 8) {
			ForEach(Array(persons.enumerated()), id: \.element.id) { index, person in
				Button {
					onSelect(person.id)
				} label: {
					AvatarCircle(isSelected: selectedID == person.id) { face(of: person) }
				}
				.buttonStyle(.plain)
				.accessibilityLabel(Text(person.name))
				.accessibilityAddTraits(selectedID == person.id ? .isSelected : [])
				.accessibilityIdentifier("people.avatar.\(index)")
				.accessibilityShowsLargeContentViewer()
				.id(Optional(person.id))
			}
			if canAdd {
				Button {
					onSelect(nil)
				} label: {
					AvatarCircle(isSelected: selectedID == nil) {
						Image(systemName: "plus")
							.font(.system(size: 16, weight: .bold))
							.foregroundStyle(.primary)
							.frame(maxWidth: .infinity, maxHeight: .infinity)
							.background(.ultraThinMaterial)
					}
				}
				.buttonStyle(.plain)
				.accessibilityLabel(Text("Add person"))
				.accessibilityAddTraits(selectedID == nil ? .isSelected : [])
				.accessibilityIdentifier("people.avatar.add")
				.accessibilityShowsLargeContentViewer()
				.id(UUID?.none)
			}
		}
		.padding(.horizontal, 16)
	}

	@ViewBuilder
	private func face(of person: Person) -> some View {
		if let image = thumbnails.thumbnail(for: person) {
			Image(uiImage: image)
				.resizable()
				.scaledToFill()
		} else {
			ZStack {
				LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
				Text(person.name.prefix(1).uppercased())
					.font(.system(size: 16, weight: .bold, design: .rounded))
					.foregroundStyle(.white)
			}
		}
	}
}
