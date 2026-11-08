import Foundation

@testable import Core

/// Preserved stores held in memory, recording each call; `failing` makes the named calls throw.
final class PreservedStoreGatewaySpy: PreservedStoreGateway, @unchecked Sendable {
	enum Call: Equatable {
		case stores, preservePhotos(String), markReported(String), export(String), delete(String), removeExports
	}

	private let lock = NSLock()
	private var held: [PreservedStore]
	private var recorded: [Call] = []
	private var failingCalls: Set<String> = []

	init(stores: [PreservedStore]) {
		held = stores
	}

	var calls: [Call] { lock.withLock { recorded } }

	func fail(_ names: Set<String>) { lock.withLock { failingCalls = names } }

	func stores() throws -> [PreservedStore] {
		try record(.stores, name: "stores")
		return lock.withLock { held }
	}

	func preservePhotos(of store: PreservedStore) throws -> PreservedStore {
		try record(.preservePhotos(store.id), name: "preservePhotos")
		return update(store) { Self.copy($0, hasPreservedPhotos: true) }
	}

	func markReported(_ store: PreservedStore) throws -> PreservedStore {
		try record(.markReported(store.id), name: "markReported")
		return update(store) { Self.copy($0, isReported: true) }
	}

	func export(_ store: PreservedStore, now: Date) throws -> URL {
		try record(.export(store.id), name: "export")
		return URL(fileURLWithPath: "/tmp/\(store.id).zip")
	}

	func delete(_ store: PreservedStore) throws {
		try record(.delete(store.id), name: "delete")
		lock.withLock { held.removeAll { $0.id == store.id } }
	}

	func removeExports() {
		lock.withLock { recorded.append(.removeExports) }
	}

	static func store(_ id: String, cause: PreservedStoreCause = .incompatibleModel(code: 134_100)) -> PreservedStore {
		PreservedStore(
			id: id, preservedAt: Date(timeIntervalSince1970: 1_800_000_000), cause: cause, appVersion: "3.1 (40)", hasPreservedPhotos: false,
			isReported: false)
	}

	private func record(_ call: Call, name: String) throws {
		try lock.withLock {
			recorded.append(call)
			if failingCalls.contains(name) { throw CocoaError(.fileWriteNoPermission) }
		}
	}

	private func update(_ store: PreservedStore, _ change: (PreservedStore) -> PreservedStore) -> PreservedStore {
		lock.withLock {
			let changed = change(held.first { $0.id == store.id } ?? store)
			held = held.map { $0.id == store.id ? changed : $0 }
			return changed
		}
	}

	private static func copy(_ store: PreservedStore, hasPreservedPhotos: Bool? = nil, isReported: Bool? = nil) -> PreservedStore {
		PreservedStore(
			id: store.id, preservedAt: store.preservedAt, cause: store.cause, appVersion: store.appVersion,
			hasPreservedPhotos: hasPreservedPhotos ?? store.hasPreservedPhotos, isReported: isReported ?? store.isReported)
	}
}
