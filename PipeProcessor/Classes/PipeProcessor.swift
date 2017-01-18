//
//  PipeProcessor.swift
//  Pods
//
//  Created by DirGoTii on 17/01/2017.
//
//

import Foundation
import Result

public protocol Context {
    
}

public struct ProcessError: Error {
    let message: String
}

public class Cancelable {
    public func cancel() {
        cancelBlock?()
    }
    
    public func add(_ block: @escaping () -> Void) {
        if let oldBlock = cancelBlock {
            cancelBlock = {
                oldBlock()
                block()
            }
        } else {
            cancelBlock = block
        }
    }
    
    public func add(_ cancelable: Cancelable) {
        add {
            cancelable.cancel()
        }
    }
    
    private var cancelBlock: (() -> Void)?
    
    public init(_ block: @escaping () -> Void) {
        cancelBlock = block
    }
    
    public init() {
        
    }
    
    public class func empty() -> Cancelable {
        return Cancelable()
    }
}

public typealias SyncProcessFunction<T: Context> = (T) -> Result<T, ProcessError>
public typealias AsyncProcessFuction<T: Context> = (T, @escaping (Result<T, ProcessError>) -> Void) -> Cancelable

public protocol Processor {
    associatedtype ContextType: Context
    var description: String { get }
}

public protocol SyncProcessor: Processor {
    func process(_ context: ContextType) -> Result<ContextType, ProcessError>
}

public protocol AsyncProcessor: Processor {
    @discardableResult func process(_ context: ContextType, complete: @escaping (Result<ContextType, ProcessError>) -> Void) -> Cancelable
}

public struct AnySyncProcessor<T: Context>: SyncProcessor {
    public typealias ContextType = T
    public func process(_ context: T) -> Result<T, ProcessError> {
        return processBlock(context)
    }
    
    public var description: String {
        return descriptionBlock()
    }
    
    let processBlock: SyncProcessFunction<T>
    let descriptionBlock: () -> String
}

public struct AnyAsyncProcessor<T: Context>: AsyncProcessor {
    public typealias ContextType = T
    @discardableResult public func process(_ context: T, complete: @escaping (Result<T, ProcessError>) -> Void) -> Cancelable {
        return processBlock(context, complete)
    }
    
    public var description: String {
        return descriptionBlock()
    }
    
    let processBlock: AsyncProcessFuction<T>
    let descriptionBlock: () -> String
}

public extension SyncProcessor {
    func appendProcessor<T: SyncProcessor>(_ processor: T) -> AnySyncProcessor<Self.ContextType> where T.ContextType == Self.ContextType {
        return AnySyncProcessor<Self.ContextType>(processBlock: { (context) -> Result<Self.ContextType, ProcessError> in
            switch self.process(context) {
            case let .success(ctx):
                return processor.process(ctx)
            case let .failure(error):
                return .failure(error)
            }
        }, descriptionBlock: { () -> String in
            return "\(self.description)>>>\(processor.description)"
        })
    }
    
    func appendProcessor<T: AsyncProcessor>(_ processor: T) -> AnyAsyncProcessor<Self.ContextType> where T.ContextType == Self.ContextType {
        return AnyAsyncProcessor<Self.ContextType>(processBlock: { (context, complete) -> Cancelable in
            switch self.process(context) {
            case let .success(ctx):
                return processor.process(ctx, complete: complete)
            case let .failure(error):
                complete(.failure(error))
                return Cancelable.empty()
            }
        }, descriptionBlock: { () -> String in
            return "\(self.description)>>>\(processor.description)"
        })
    }
}

public extension AsyncProcessor {
    func appendProcessor<T: SyncProcessor>(_ processor: T) -> AnyAsyncProcessor<Self.ContextType> where T.ContextType == Self.ContextType {
        return AnyAsyncProcessor<Self.ContextType>(processBlock: { (context, complete) -> Cancelable in
            return self.process(context, complete: { (result) in
                switch result {
                case let .success(ctx):
                    complete(processor.process(ctx))
                case let .failure(error):
                    complete(.failure(error))
                }
            })
        }, descriptionBlock: { () -> String in
            return "\(self.description)>>>\(processor.description)"
        })
    }
    
    func appendProcessor<T: AsyncProcessor>(_ processor: T) -> AnyAsyncProcessor<Self.ContextType> where T.ContextType == Self.ContextType {
        return AnyAsyncProcessor<Self.ContextType>(processBlock: { (context, complete) -> Cancelable in
            let cancelable = Cancelable.empty()
            cancelable.add(self.process(context, complete: { (result) in
                switch result {
                case let .success(ctx):
                    cancelable.add(processor.process(ctx, complete: complete))
                case let .failure(error):
                    complete(.failure(error))
                }
            }))
            return cancelable
        }, descriptionBlock: { () -> String in
            return "\(self.description)>>>\(processor.description)"
        })
    }
}

precedencegroup Left {
    associativity: left
}

infix operator >>> : Left

public func >>> <T: SyncProcessor, G: SyncProcessor> (l: T, r: G) -> AnySyncProcessor<T.ContextType> where T.ContextType == G.ContextType {
    return l.appendProcessor(r)
}

public func >>> <T: SyncProcessor, G: AsyncProcessor> (l: T, r: G) -> AnyAsyncProcessor<T.ContextType> where T.ContextType == G.ContextType {
    return l.appendProcessor(r)
}

public func >>> <T: AsyncProcessor, G: SyncProcessor> (l: T, r: G) -> AnyAsyncProcessor<T.ContextType> where T.ContextType == G.ContextType {
    return l.appendProcessor(r)
}

public func >>> <T: AsyncProcessor, G: AsyncProcessor> (l: T, r: G) -> AnyAsyncProcessor<T.ContextType> where T.ContextType == G.ContextType {
    return l.appendProcessor(r)
}
