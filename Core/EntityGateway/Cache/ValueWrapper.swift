import Foundation

final class ValueWrapper<ValueType> {
	let created: Date
	var expiration: Date?
	let value: ValueType

	init(value: ValueType, expiration: Date? = nil) {
		created = Date()
		self.expiration = expiration
		self.value = value
	}
}
