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

extension UIImage: Context {
    
}

class ProcessorA: SyncProcessor {
    typealias ContextType = UIImage
    
    func process(_ context: UIImage) -> Result<UIImage, ProcessError> {
        return .success(context)
    }
    
    var description: String {
        get {
            return "ProcessorA"
        }
    }
}

class ProcessorB: AsyncProcessor {
    typealias ContextType = UIImage
    
    @discardableResult func process(_ context: UIImage, complete: @escaping (Result<UIImage, ProcessError>) -> Void) -> Cancelable {
        var canceled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !canceled {
                complete(.success(context))
            }
        }
        return Cancelable {
            canceled = true
            debugPrint("Cancel")
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

