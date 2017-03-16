//
//  PipeProcessor.swift
//  Pods
//
//  Created by DirGoTii on 17/01/2017.
//
//

import Foundation
import Result

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

public typealias SyncProcessFunction<Input, Output, Error: Swift.Error> = (Input, Any?) -> Result<Output, Error>
public typealias AsyncProcessFuction<Input, Output, Error: Swift.Error> = (Input, Any?, @escaping (Result<Output, Error>) -> Void) -> Cancelable

public protocol Processor {
    associatedtype Input
    associatedtype Output
    associatedtype Error: Swift.Error
    var description: String { get }
}

public protocol SyncProcessor: Processor {
    func process(_ input: Input, info: Any?) -> Result<Output, Error>
}

public protocol AsyncProcessor: Processor {
    @discardableResult func process(_ input: Input, info: Any?, complete: @escaping (Result<Output, Error>) -> Void) -> Cancelable
}

public struct AnySyncProcessor<InputType, OutputType, ErrorType: Swift.Error>: SyncProcessor {
    public typealias Input = InputType
    public typealias Output = OutputType
    public typealias Error = ErrorType
    public func process(_ input: Input, info: Any? = nil) -> Result<Output, Error> {
        return processBlock(input, info)
    }
    
    public var description: String {
        return descriptionBlock()
    }
    
    let processBlock: SyncProcessFunction<Input, Output, Error>
    let descriptionBlock: () -> String
}

public struct AnyAsyncProcessor<InputType, OutputType, ErrorType: Swift.Error>: AsyncProcessor {
    public typealias Input = InputType
    public typealias Output = OutputType
    public typealias Error = ErrorType
    @discardableResult public func process(_ input: Input, info: Any? = nil, complete: @escaping (Result<Output, Error>) -> Void) -> Cancelable {
        return processBlock(input, info, complete)
    }
    
    public var description: String {
        return descriptionBlock()
    }
    
    let processBlock: AsyncProcessFuction<Input, Output, Error>
    let descriptionBlock: () -> String
    
    public init(processBlock: @escaping AsyncProcessFuction<Input, Output, Error>, descriptionBlock: @escaping () -> String) {
        self.processBlock = processBlock
        self.descriptionBlock = descriptionBlock
    }
}

public extension SyncProcessor {
    func appendProcessor<T: SyncProcessor>(_ processor: T) -> AnySyncProcessor<Input, T.Output, T.Error> where Output == T.Input, Error == T.Error {
        return AnySyncProcessor<Input, T.Output, Error>(processBlock: { (input, info) -> Result<T.Output, T.Error> in
            switch self.process(input, info: info) {
            case let .success(ctx):
                return processor.process(ctx, info: info)
            case let .failure(error):
                return .failure(error)
            }
        }, descriptionBlock: { () -> String in
            return "\(self.description)>>>\(processor.description)"
        })
    }
    
    func appendProcessor<T: AsyncProcessor>(_ processor: T) -> AnyAsyncProcessor<Input, T.Output, T.Error> where Output == T.Input, Error == T.Error {
        return AnyAsyncProcessor<Input, T.Output, T.Error>(processBlock: { (input, info, complete) -> Cancelable in
            switch self.process(input, info: info) {
            case let .success(ctx):
                return processor.process(ctx, info: info, complete: complete)
            case let .failure(error):
                complete(.failure(error))
                return Cancelable.empty()
            }
        }, descriptionBlock: { () -> String in
            return "\(self.description)>>>\(processor.description)"
        })
    }
    
    
    public var async: AnyAsyncProcessor<Input, Output, Error> {
        get {
            return AnyAsyncProcessor<Input, Output, Error>(processBlock: { (input, info, complete) -> Cancelable in
                let result = self.process(input, info: info)
                complete(result)
                return Cancelable.empty()
            }, descriptionBlock: { () -> String in
                return self.description
            })
        }
    }
}

public extension AsyncProcessor {
    func appendProcessor<T: SyncProcessor>(_ processor: T) -> AnyAsyncProcessor<Input, T.Output, T.Error> where Output == T.Input, Error == T.Error {
        return AnyAsyncProcessor<Input, T.Output, T.Error>(processBlock: { (input, info, complete) -> Cancelable in
            return self.process(input, info: info, complete: { (result) in
                switch result {
                case let .success(ctx):
                    complete(processor.process(ctx, info: info))
                case let .failure(error):
                    complete(.failure(error))
                }
            })
        }, descriptionBlock: { () -> String in
            return "\(self.description)>>>\(processor.description)"
        })
    }
    
    func appendProcessor<T: AsyncProcessor>(_ processor: T) -> AnyAsyncProcessor<Input, T.Output, T.Error> where Output == T.Input, Error == T.Error {
        return AnyAsyncProcessor<Input, T.Output, T.Error>(processBlock: { (input, info, complete) -> Cancelable in
            let cancelable = Cancelable.empty()
            cancelable.add(self.process(input, info: info, complete: { (result) in
                switch result {
                case let .success(ctx):
                    cancelable.add(processor.process(ctx, info: info, complete: complete))
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

public func >>> <T: SyncProcessor, G: SyncProcessor> (l: T, r: G) -> AnySyncProcessor<T.Input, G.Output, T.Error> where T.Output == G.Input, T.Error == G.Error {
    return l.appendProcessor(r)
}

public func >>> <T: SyncProcessor, G: AsyncProcessor> (l: T, r: G) -> AnyAsyncProcessor<T.Input, G.Output, T.Error> where T.Output == G.Input, T.Error == G.Error {
    return l.appendProcessor(r)
}

public func >>> <T: AsyncProcessor, G: SyncProcessor> (l: T, r: G) -> AnyAsyncProcessor<T.Input, G.Output, T.Error> where T.Output == G.Input, T.Error == G.Error {
    return l.appendProcessor(r)
}

public func >>> <T: AsyncProcessor, G: AsyncProcessor> (l: T, r: G) -> AnyAsyncProcessor<T.Input, G.Output, T.Error> where T.Output == G.Input, T.Error == G.Error {
    return l.appendProcessor(r)
}
