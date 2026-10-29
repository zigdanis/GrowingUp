//
//  CoreError.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import Foundation

private let bundle = Bundle(identifier: Constants.bundleIdentifier)!

public struct CoreError: Error, Equatable {

	public var localizedDescription: String { return message }
	public var title = ""
	public var message = ""
	/// The domain and code of the error this one wraps, if any. They name the cause for crash reports without the
	/// message, which can quote the record that failed.
	public private(set) var underlyingDomain: String?
	public private(set) var underlyingCode: Int?

	public init(title: String = "Error", message: String) {
		self.title = NSLocalizedString(title, bundle: bundle, comment: "Error Title")
		self.message = NSLocalizedString(message, bundle: bundle, comment: "Error Message")
	}

	public init(error: Error) {
		self.title = "Error"
		self.message = error.localizedDescription
		if let wrapped = error as? CoreError {
			underlyingDomain = wrapped.underlyingDomain
			underlyingCode = wrapped.underlyingCode
		} else {
			underlyingDomain = (error as NSError).domain
			underlyingCode = (error as NSError).code
		}
		checkForSpecificCoreDataError()
	}

	/// Errors are equal when they tell the user the same; the wrapped cause does not count.
	public static func == (lhs: CoreError, rhs: CoreError) -> Bool {
		lhs.title == rhs.title && lhs.message == rhs.message
	}

	private mutating func checkForSpecificCoreDataError() {
		if message.contains("widgetPersons") {
			self = Self.widgetPeopleLimitReached
		}
	}

	public static let failedToCreateDate = CoreError(message: "Can't create Date value from specified parameters")
	public static let widgetPeopleLimitReached = CoreError(message: "Unable to add more than 6 persons")
	public static let noNameValue = CoreError(message: "Can't save person without specified name")
	public static let noDayValue = CoreError(message: "Can't save person without specified day of birth")
	public static let noTimeValue = CoreError(message: "Can't save person without specified time of birth")
	public static let coreDataInit = CoreError(message: "Failed initializing Core Data stack")
	public static let coreDataAddFailed = CoreError(message: "Failed adding entity to the data base")
	public static let coreDataFetchFailed = CoreError(message: "Failed retrieving entities from the data base")
	public static let coreDataSaveFailed = CoreError(message: "Failed saving the context")
	public static let asyncWorkError = CoreError(
		message: "Asyncronous work were not finished before final notification called")
	public static let missingValue = CoreError(message: "Missing value")
	public static let unknownError = CoreError(message: "Unknown error occured")
}
