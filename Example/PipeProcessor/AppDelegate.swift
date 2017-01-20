//
//  AppDelegate.swift
//  PipeProcessor
//
//  Created by Tulipa on 01/17/2017.
//  Copyright (c) 2017 Tulipa. All rights reserved.
//

import UIKit
import Result
import PipeProcessor

extension String: Error {
    
}

class ProcessorA: SyncProcessor {
    typealias Input = UIImage
    typealias Output = UIImage
    typealias Error = String
    
    func process(_ input: UIImage) -> Result<UIImage, String> {
        return .success(input)
    }
    
    var description: String {
        get {
            return "ProcessorA"
        }
    }
}

class ProcessorB: AsyncProcessor {
    typealias Input = UIImage
    typealias Output = UIImage
    typealias Error = String
    
    func process(_ input: UIImage, complete: @escaping (Result<UIImage, String>) -> Void) -> Cancelable {
        complete(.success(input))
        return Cancelable {
            
        }
    }
    
    var description: String {
        get {
            return "ProcessorB"
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    
        let a = ProcessorA()
        let b = ProcessorB()
        
        let image = UIImage()
        
        let process = a >>> b >>> a >>> b
        
        process.process(image) { (result) in
            debugPrint(result)
        }
        
        debugPrint(process.description)
        
        return true
    }

    
}

