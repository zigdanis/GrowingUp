//
//  Logging.swift
//  GrowingUp
//
//  Created by zigdanis on 12/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

public enum Logging {

  public static func setup() {
  }

  public static func logError(_ error: CoreError) {
    let value = "❌ \(error.title)\n\(error.message)"
    print(value)
  }

  public static func logMessage(_ message: String, params: [String: String]? = nil) {
    let value = "✍️ \(message)"
    print(value)
  }

  public static func logWarning(_ warning: String) {
    let value = "⚠️ \(warning)"
    print(value)
  }
}
