//
//  ImagesCache.swift
//  GrowingUp
//
//  Created by zigdanis on 17/04/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Disk
import Foundation
import UIKit

public enum ImagesCache {

  public static let memoryCache = MemoryCache<UIImage>()

  public static func loadImageFromDiskOrMemory(
    image: PersonImage, completion: @escaping (Result<UIImage, CoreError>) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      var result = Result<UIImage, CoreError>.failure(.unknownError)
      if let memoryImg = memoryCache.value(forKey: image.cachingKey) {
        result = .success(memoryImg)
      } else {
        let directory = Disk.Directory.sharedContainer(appGroupName: Constants.appGroupId)
        do {
          let image = try Disk.retrieve(image.cachingKey, from: directory, as: UIImage.self)
          result = .success(image)
        } catch {
          let coreError = CoreError(error: error)
          result = .failure(coreError)
        }
      }
      DispatchQueue.main.async {
        completion(result)
      }
    }
  }
}
