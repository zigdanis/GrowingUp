//
//  AddPersonConfigurator.swift
//  Aging
//
//  Created by zigdanis on 14/03/2019.
//  Copyright © 2019 zigdanis. All rights reserved.
//

import Foundation

protocol AddPersonConfigurator {
    func configure(addPersonViewController: AddPersonViewController)
}

class AddPersonConfiguratorImplementation: AddPersonConfigurator {
    
    var addPersonPresenterDelegate: AddPersonPresenterDelegate?
    
    init(addPersonPresenterDelegate: AddPersonPresenterDelegate?) {
        self.addPersonPresenterDelegate = addPersonPresenterDelegate
    }
    
    func configure(addPersonViewController: AddPersonViewController) {
        
//        let personsGateway = CacheBooksGateway(apiBooksGateway: apiBooksGateway,
//                                             localPersistenceBooksGateway: coreDataBooksGateway)
//        
//        let addBookUseCase = AddBookUseCaseImplementation(booksGateway: booksGateway)
//        let router = AddBookViewRouterImplementation(addBookViewController: addBookViewController)
//        
//        let presenter = AddBookPresenterImplementation(view: addBookViewController, addBookUseCase: addBookUseCase, router: router, delegate: addBookPresenterDelegate)
//        
//        addBookViewController.presenter = presenter
    }
}
