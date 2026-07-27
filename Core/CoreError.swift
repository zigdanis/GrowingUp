//
//  CoreError.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

private let bundle = Bundle(identifier: Constants.bundleIdentifier)!

public struct CoreError: Error, Equatable {

  public var localizedDescription: String { return message }
  public var title = ""
  public var message = ""

  public init(title: String = "Error", message: String) {
    self.title = NSLocalizedString(title, bundle: bundle, comment: "Error Title")
    self.message = NSLocalizedString(message, bundle: bundle, comment: "Error Message")
  }

  public init(error: Error) {
    self.title = "Error"
    self.message = error.localizedDescription
    checkForSpecificCoreDataError()
  }

  private mutating func checkForSpecificCoreDataError() {
    if message.contains("widgetPersons") {
      let threePersons = "Unable to add more than 3 persons"
      self.message = NSLocalizedString(threePersons, bundle: bundle, comment: "Error Message")
    }
  }

  public static let failedToCreateDate = CoreError(message: "Can't create Date value from specified parameters")
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
