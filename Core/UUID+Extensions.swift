//
//  UUID+Extensions.swift
//  Core
//
//  Created by zigdanis on 29/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

extension UUID {

  init?(string: String?) {
    guard let string = string else { return nil }
    self.init(uuidString: string)
  }
}
