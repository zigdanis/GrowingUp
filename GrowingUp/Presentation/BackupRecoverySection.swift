import Core
import SwiftUI

/// The first section of Settings while store recovery keeps earlier data aside: the one preserved copy, or with
/// several (recovery can happen again), one row for each.
struct BackupRecoverySection: View {
	let stores: [PreservedStore]

	var body: some View {
		Section {
			if stores.count == 1, let store = stores.first {
				NavigationLink(value: store) {
					Label("Earlier data preserved", systemImage: "archivebox")
				}
				.accessibilityIdentifier("backup.preservedData")
			} else {
				ForEach(stores) { store in
					NavigationLink(value: store) {
						Label(
							"Earlier data from \(store.preservedAt.formatted(date: .long, time: .omitted))", systemImage: "archivebox")
					}
				}
			}
		}
	}
}
