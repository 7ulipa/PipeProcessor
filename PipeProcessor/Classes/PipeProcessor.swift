//
//  PipeProcessor.swift
//  Pods
//
//  Created by DirGoTii on 17/01/2017.
//
//

import Foundation

public enum Result<T, Error> {
    case success(T)
    case error(Error)
}

public protocol Context {
    
}

public protocol ProcessError {
    
}

public typealias SyncProcessFunction<T: Context> = (T) -> Result<T, ProcessError>
public typealias AsyncProcessFuction<T: Context> = (T, (Result<T, ProcessError>) -> Void) -> Void

public protocol Processor {
    associatedtype ContextType: Context
    
    var description: String { get }
}

public protocol SyncProcessor: Processor {
    func process(_ context: ContextType) -> Result<ContextType, ProcessError>
}

public protocol AsyncProcessor: Processor {
    func process(_ context: ContextType, complete: (Result<ContextType, ProcessError>) -> Void)
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
    public func process(_ context: T, complete: (Result<T, ProcessError>) -> Void) {
        processBlock(context, complete)
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
            case let .error(error):
                return .error(error)
            }
        }, descriptionBlock: { () -> String in
            return "\(self.description)>>>\(processor.description)"
        })
    }
    
    func appendProcessor<T: AsyncProcessor>(_ processor: T) -> AnyAsyncProcessor<Self.ContextType> where T.ContextType == Self.ContextType {
        return AnyAsyncProcessor<Self.ContextType>(processBlock: { (context, complete) in
            switch self.process(context) {
            case let .success(ctx):
                processor.process(ctx, complete: complete)
            case let .error(error):
                complete(.error(error))
            }
        }, descriptionBlock: { () -> String in
            return "\(self.description)>>>\(processor.description)"
        })
    }
}

public extension AsyncProcessor {
    func appendProcessor<T: SyncProcessor>(_ processor: T) -> AnyAsyncProcessor<Self.ContextType> where T.ContextType == Self.ContextType {
        return AnyAsyncProcessor<Self.ContextType>(processBlock: { (context, complete) in
            self.process(context, complete: { (result) in
                switch result {
                case let .success(ctx):
                    complete(processor.process(ctx))
                case let .error(error):
                    complete(.error(error))
                }
            })
        }, descriptionBlock: { () -> String in
            return "\(self.description)>>>\(processor.description)"
        })
    }
    
    func appendProcessor<T: AsyncProcessor>(_ processor: T) -> AnyAsyncProcessor<Self.ContextType> where T.ContextType == Self.ContextType {
        return AnyAsyncProcessor<Self.ContextType>(processBlock: { (context, complete) in
            self.process(context, complete: { (result) in
                switch result {
                case let .success(ctx):
                    processor.process(ctx, complete: complete)
                case let .error(error):
                    complete(.error(error))
                }
            })
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
