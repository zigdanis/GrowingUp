//
//  CoreDataPersonsGateway.swift
//  Aging
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

class CoreDataPersonsGateway: PersonsGateway {
    
    let viewContext: NSManagedObjectContextProtocol
    
    init(viewContext: NSManagedObjectContextProtocol) {
        self.viewContext = viewContext
    }
    
    func add(parameters: AddPersonParameters, completionHandler: @escaping AddPersonEntityGatewayCompletionHandler) {
        guard let coreDataPerson = viewContext.addEntity(withType: CoreDataPerson.self) else {
            let error = CoreError(message: "Failed adding the person in the data base")
            let result = Result<Person>.failure(error)
            return completionHandler(result)
        }
        
        coreDataPerson.populate(with: parameters)
        
        do {
            try viewContext.save()
            completionHandler(.success(coreDataPerson.person))
        } catch {
            viewContext.delete(coreDataPerson)
            completionHandler(.failure(CoreError(message: "Failed saving the context")))
        }
    }
    
    func fetchPersons(completionHandler: @escaping FetchPersonsEntityGatewayCompletionHandler) {
        
    }
    
    func delete(person: Person, completionHandler: @escaping DeletePersonEntityGatewayCompletionHandler) {
        
    }
    
    
}
