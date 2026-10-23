import Core
import SwiftUI

/// The home screen's grid of people tiles in mosaic order; a tile opens that person full screen, zooming out of it.
struct PeopleMosaic: View {
	let persons: [Person]
	let pictures: MosaicPicturesPresenter
	/// The person to keep in view: the one the viewer shows, so it closes into a visible tile, or a newly added one.
	let selectedID: UUID?
	/// Gives the mosaic an even number of columns, so no tile straddles the fold of a landscape iPhone Duo.
	let evenColumns: Bool
	let zoom: Namespace.ID
	let now: () -> Date
	let onOpen: (UUID) -> Void

	var body: some View {
		GeometryReader { geometry in
			let grid = MosaicGridLayout(size: geometry.size, count: persons.count, evenColumns: evenColumns)
			ScrollViewReader { proxy in
				ScrollView {
					LazyVGrid(
						columns: Array(repeating: GridItem(.fixed(grid.tileWidth), spacing: MosaicGridLayout.spacing), count: grid.columns),
						spacing: MosaicGridLayout.spacing
					) {
						ForEach(persons, id: \.id) { person in
							tile(person)
								.frame(width: grid.tileWidth, height: grid.tileHeight)
						}
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, MosaicGridLayout.spacing)
				}
				.scrollIndicators(.hidden)
				.onChange(of: selectedID) { _, id in
					guard let id else { return }
					withAnimation { proxy.scrollTo(id, anchor: .center) }
				}
			}
		}
	}

	private func tile(_ person: Person) -> some View {
		Button {
			onOpen(person.id)
		} label: {
			MosaicTile(person: person, picture: pictures.picture(for: person)?.image, now: now)
		}
		.buttonStyle(.plain)
		// Optional, like the viewer's selection it is matched against.
		.matchedTransitionSource(id: Optional(person.id), in: zoom) { source in
			source.clipShape(.rect(cornerRadius: MosaicTile.cornerRadius))
		}
		.accessibilityIdentifier("people.tile")
		.id(person.id)
	}
}
