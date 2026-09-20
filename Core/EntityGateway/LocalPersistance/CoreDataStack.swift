//
//  CoreDataStack.swift
//  GrowingUp
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019-2026 Danis Ziganshin.
//

import CoreData
import Foundation

public protocol CoreDataStack {
	var persistentContainer: NSPersistentContainer { get }
}
