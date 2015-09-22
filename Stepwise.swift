//
//  Stepwise.swift
//  Webs
//
//  Copyright (c) 2014, Webs <kevin@webs.com>
//
//  Permission to use, copy, modify, and/or distribute this software for any
//      purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
//  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
//  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

import Foundation

// TODO: Any protocol additions here?

public var StepDebugLoggingEnabled = false
private func stepwisePrint<T>(x: T) {
    if StepDebugLoggingEnabled {
        debugPrint(x)
    }
}

private let DefaultStepQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

// MARK: Synchronous Steps

/// Package the supplied closure as the first step in a chain.
/// Schedules the nameless step on default global queue.
///
/// - parameter body: The body of the step, which takes `InputType` as input and outputs `OutputType`.
/// - returns: A StepChain object. Can be extended with then() and started with start().
public func toStep<InputType, OutputType>(body: InputType throws -> OutputType) -> StepChain<InputType, OutputType, InputType, OutputType> {
    return toStep(named: nil, inQueue: DefaultStepQueue, body: body)
}

/// Package the supplied closure as the first step, named name, in a chain.
/// Schedules on default global queue.
///
/// - parameter named: Name of the step. Logged for debugging.
/// - parameter body: The body of the step, which takes `InputType` as input and outputs `OutputType`.
/// - returns: A StepChain object. Can be extended with then() and started with start().
public func toStep<InputType, OutputType>(named name: String?, body: InputType throws -> OutputType) -> StepChain<InputType, OutputType, InputType, OutputType> {
    return toStep(named: name, inQueue: DefaultStepQueue, body: body)
}

/// Package the supplied closure on queue as the first step in a chain.
/// Schedules a nameless step.
///
/// - parameter inQueue: Queue on which to execute the step.
/// - parameter body: The body of the step, which takes `InputType` as input and outputs `OutputType`.
/// - returns: A StepChain object. Can be extended with then() and started with start().
public func toStep<InputType, OutputType>(inQueue queue: dispatch_queue_t!, body: InputType throws -> OutputType) -> StepChain<InputType, OutputType, InputType, OutputType> {
    return toStep(named: nil, inQueue: queue, body: body)
}

/// Package the supplied closure on queue as the first step, named name, in a chain.
///
/// - parameter name: Name of the step. Logged for debugging.
/// - parameter inQueue: Queue on which to execute the step.
/// - parameter body: The body of the step, which takes `InputType` as input and outputs `OutputType`.
/// - returns: A StepChain object. Can be extended with then() and started with start().
public func toStep<InputType, OutputType>(named name: String?, inQueue: dispatch_queue_t!, body: InputType throws -> OutputType) -> StepChain<InputType, OutputType, InputType, OutputType> {
    let step = StepNode<InputType, OutputType>(name: name, queue: inQueue, body: body)
    return StepChain(step, step)
}

// MARK: Asynchronous Steps

/// Package the supplied closure as the first step in a chain.
/// Schedules the nameless step on default global queue.
/// Uses a `Handler` to pass or fail this step in the chain.
///
/// - parameter asyncBody: The body of the step, which takes `InputType` and a `Handler` that can pass or fail the step.
/// - returns: A StepChain object. Can be extended with then() and started with start().
public func toStep<InputType, OutputType>(asyncBody: (InputType, Handler<OutputType>) -> ()) -> StepChain<InputType, OutputType, InputType, OutputType> {
    return toStep(named: nil, inQueue: DefaultStepQueue, asyncBody: asyncBody)
}

/// Package the supplied closure as the first step, named name, in a chain.
/// Schedules on default global queue.
/// Uses a `Handler` to pass or fail this step in the chain.
///
/// - parameter name: Name of the step. Logged for debugging.
/// - parameter asyncBody: The body of the step, which takes `InputType` and a `Handler` that can pass or fail the step.
/// - returns: A StepChain object. Can be extended with then() and started with start().
public func toStep<InputType, OutputType>(named name: String?, asyncBody: (InputType, Handler<OutputType>) -> ()) -> StepChain<InputType, OutputType, InputType, OutputType> {
    return toStep(named: name, inQueue: DefaultStepQueue, asyncBody: asyncBody)
}

/// Package the supplied closure on queue as the first step in a chain.
/// Schedules a nameless step.
/// Uses a `Handler` to pass or fail this step in the chain.
///
/// - parameter inQueue: Queue on which to execute the step.
/// - parameter asyncBody: The body of the step, which takes `InputType` and a `Handler` that can pass or fail the step.
/// - returns: A StepChain object. Can be extended with then() and started with start().
public func toStep<InputType, OutputType>(inQueue queue: dispatch_queue_t!, asyncBody: (InputType, Handler<OutputType>) -> ()) -> StepChain<InputType, OutputType, InputType, OutputType> {
    return toStep(named: nil, inQueue: queue, asyncBody: asyncBody)
}

/// Package the supplied closure on queue as the first step, named name, in a chain.
/// Uses a `Handler` to pass or fail this step in the chain.
///
/// - parameter name: Name of the step. Logged for debugging.
/// - parameter inQueue: Queue on which to execute the step.
/// - parameter asyncBody: The body of the step, which takes `InputType` and a `Handler` that can pass or fail the step.
/// - returns: A StepChain object. Can be extended with then() and started with start().
public func toStep<InputType, OutputType>(named name: String?, inQueue: dispatch_queue_t!, asyncBody: (InputType, Handler<OutputType>) -> ()) -> StepChain<InputType, OutputType, InputType, OutputType>  {
    let step = StepNode(name: name, queue: inQueue, asyncBody: asyncBody)
    return StepChain(step, step)
}

public struct Handler<OutputType> {
    private let passClosure : OutputType -> ()
    private let failClosure : ErrorType -> ()
    
    public func pass(output: OutputType) {
        passClosure(output)
    }
    
    public func fail(error: ErrorType) {
        failClosure(error)
    }
}

/// A closure that accepts an ErrorType. Used when handling errors in Steps.
public typealias StepErrorHandler = (ErrorType) -> ()

/// The result of any Step scheduling operation (step(), then()).
/// Provides a model that can be started or canceled.
/// New operations can be added to the chain with then().
/// StepChains are not reusable and can only be started once.
public class StepChain<StartInputType, StartOutputType, CurrentInputType, CurrentOutputType> {
    /// A CancellationToken that provides a one-time cancel operation that will abort execution at whatever step is currently in progress.
    public var cancellationToken : CancellationToken { return firstNode.cancellationToken }
    
    // Private node-tracking.
    private let firstNode : StepNode<StartInputType, StartOutputType>
    private let lastNode : StepNode<CurrentInputType, CurrentOutputType>
    
    private init(_ first: StepNode<StartInputType, StartOutputType>, _ last: StepNode<CurrentInputType, CurrentOutputType>) {
        self.firstNode = first
        self.lastNode = last
    }
    
    // MARK: Synchronous Steps
    
    /// Execute a new step after this one.
    ///
    /// - parameter body: The body of the step, which takes `InputType` as input and outputs `OutputType`.
    /// - returns: A new StepChain that ends in the added step. Can be extended with then() and started with start().
    public func then<NextOutputType>(body: CurrentOutputType throws -> NextOutputType) -> StepChain<StartInputType, StartOutputType, CurrentOutputType, NextOutputType> {
        return then(nil, inQueue: DefaultStepQueue, body: body)
    }
    
    /// Execute a new step after this one on a given dispatch queue.
    ///
    /// - parameter queue: The queue on which to execute the step. Defaults to default priority global queue.
    /// - parameter body: The body of the step, which takes `InputType` as input and outputs `OutputType`.
    /// - returns: A new StepChain that ends in the added step. Can be extended with then() and started with start().
    public func then<NextOutputType>(inQueue queue: dispatch_queue_t!, body: CurrentOutputType throws -> NextOutputType) -> StepChain<StartInputType, StartOutputType, CurrentOutputType, NextOutputType> {
        return then(nil, inQueue: queue, body: body)
    }
    
    /// Execute a new step named name after this one.
    ///
    /// - parameter name: The name of the step. Defaults to nil.
    /// - parameter body: The body of the step, which takes `InputType` as input and outputs `OutputType`.
    /// - returns: A new StepChain that ends in the added step. Can be extended with then() and started with start().
    public func then<NextOutputType>(name: String?, body: CurrentOutputType throws -> NextOutputType) -> StepChain<StartInputType, StartOutputType, CurrentOutputType, NextOutputType> {
        return then(name, inQueue: DefaultStepQueue, body: body)
    }
    
    /// Add a new step named name on queue to the receiver and return the result.
    ///
    /// - parameter name: The name of the step. Defaults to nil.
    /// - parameter queue: The queue on which to execute the step. Defaults to default priority global queue.
    /// - parameter body: The body of the step, which takes `InputType` as input and outputs `OutputType`.
    /// - returns: A new StepChain that ends in the added step. Can be extended with then() and started with start().
    public func then<NextOutputType>(name: String?, inQueue queue: dispatch_queue_t!, body: CurrentOutputType throws -> NextOutputType) -> StepChain<StartInputType, StartOutputType, CurrentOutputType, NextOutputType> {
        let step = StepNode<CurrentOutputType, NextOutputType>(name: name, queue: queue, body: body)
        return then(step)
    }
    
    // MARK: Asynchronous Steps
    
    public func then<NextOutputType>(asyncBody: (CurrentOutputType, Handler<NextOutputType>) -> ()) -> StepChain<StartInputType, StartOutputType, CurrentOutputType, NextOutputType> {
        return then(nil, inQueue: DefaultStepQueue, asyncBody: asyncBody)
    }
    
    public func then<NextOutputType>(inQueue queue: dispatch_queue_t!, asyncBody: (CurrentOutputType, Handler<NextOutputType>) -> ()) -> StepChain<StartInputType, StartOutputType, CurrentOutputType, NextOutputType> {
        return then(nil, inQueue: queue, asyncBody: asyncBody)
    }
    
    public func then<NextOutputType>(name: String?, asyncBody: (CurrentOutputType, Handler<NextOutputType>) -> ()) -> StepChain<StartInputType, StartOutputType, CurrentOutputType, NextOutputType> {
        return then(name, inQueue: DefaultStepQueue, asyncBody: asyncBody)
    }
    
    public func then<NextOutputType>(name: String?, inQueue queue: dispatch_queue_t!, asyncBody: (CurrentOutputType, Handler<NextOutputType>) -> ()) -> StepChain<StartInputType, StartOutputType, CurrentOutputType, NextOutputType> {
        let step = StepNode<CurrentOutputType, NextOutputType>(name: name, queue: queue, asyncBody: asyncBody)
        return then(step)
    }
    
    // MARK: Convenience
    
    /// Add all steps in chain to the receiver and return the result.
    ///
    /// - parameter chain: The StepChain to append to the receiver.
    /// - returns: A new StepChain that includes all steps in the receiver, then all steps in chain. Can be extended with then() and started with start().
    public func then<Value1, Value2, Value3>(chain: StepChain<CurrentOutputType, Value1, Value2, Value3>) -> StepChain<StartInputType, StartOutputType, Value2, Value3> {
        // Connect first step of incoming chain
        lastNode.then(chain.firstNode)
        
        // Return last step of incoming chain
        return StepChain<StartInputType, StartOutputType, Value2, Value3>(firstNode, chain.lastNode)
    }
    
    private func then<NextOutputType>(nextStep: StepNode<CurrentOutputType, NextOutputType>) -> StepChain<StartInputType, StartOutputType, CurrentOutputType, NextOutputType> {
        lastNode.then(nextStep)
        return StepChain<StartInputType, StartOutputType, CurrentOutputType, NextOutputType>(firstNode, nextStep)
    }
    
    /// Begins execution of each step in the chain, in order.
    ///
    /// - parameter input: The input for the first step.
    public func start(input: StartInputType) -> StepChain {
        firstNode.start(input)
        return self
    }
    
    /// Adds an error handler to every step in the chain.
    ///
    /// - note: Each chain may only have a single error handler.
    /// - parameter errorHandler: The handler to add to the chain.
    /// - returns: The step chain.
    public func onError(errorHandler: StepErrorHandler) -> StepChain<StartInputType, StartOutputType, CurrentInputType, CurrentOutputType> {
        firstNode.errorHandler = errorHandler
        return self
    }
    
    /// Schedules a handler to be executed after the chain ends or is broken by error or cancellation.
    /// A handler scheduled with finally() will always execute.
    /// The single enum argument to the handler block marks the final state of the chain.
    ///
    /// - parameter handler: The handler to be executed when the chain ends.
    /// - returns: The step chain.
    public func finally(handler: (ChainState) -> ()) -> StepChain<StartInputType, StartOutputType, CurrentInputType, CurrentOutputType> {
        // We place this on the first node although it's logically executed on the last because we may never reach the last—
        // if the event of an error, the chain is broken. So we want to pass along from the very first node.
        firstNode.finallyHandler = handler
        return self
    }
}

/// A token that can signal a one-time cancellation of a step chain.
/// An optional reason can be given and will be logged.
public class CancellationToken {
    /// Whether the token was given a cancel signal.
    public var cancelled : Bool {
        var result : Bool = false
        dispatch_sync(queue) {
            result = self._cancelled
        }
        return result
    }
    /// An optional reason supplied when the cancel signal was sent.
    public var reason : String?
    
    private let queue = dispatch_queue_create("com.pagemodo.posts.cancel-token.lock", nil)
    private var _cancelled : Bool = false
    
    /// Marks the token as cancelled. Irreversible.
    /// All steps with this token will check for cancellation and cease execution if true.
    ///
    /// - parameter reason: An optional reason for canceling. Defaults to nil.
    /// - returns: true if cancel was successful, false if the token was already cancelled.
    public func cancel(reason: String? = nil) -> Bool {
        if self._cancelled { return false }
        dispatch_sync(queue) {
            self._cancelled = true
            self.reason = reason
        }
        return true
    }
}

/// Used to identify how a StepChain entered a finally() block. See finally().
public enum ChainState {
    // TODO: Any way to not make this Any? Generics don't work b/c we pass the handler along the chain.
    /// The step chain resolved successfully. Contains the final output of the chain.
    case Resolved(Any)
    /// The step chain ended in error. Contains the error passed to Step.error().
    case Errored(ErrorType)
    /// The step chain was canceled. Contains the cancellation token, which may be queried for a String reason.
    case Canceled(CancellationToken)
    
    // Convenience methods
    
    /// - returns: true if chain was resolved successfully.
    public var resolved : Bool {
        switch self {
            case .Resolved(_): return true
            default: return false
        }
    }
    
    /// - returns: true if chain errored.
    public var errored : Bool {
        switch self {
            case .Errored(_): return true
            default: return false
        }
    }
    
    /// - returns: true if chain was canceled.
    public var canceled : Bool {
        switch self {
            case .Canceled(_): return true
            default: return false
        }
    }
}

/// MARK: Private

// Node that encapsulates each step body in the chain
private class StepNode<InputType, OutputType> : CustomDebugStringConvertible {
    typealias StepBody = InputType throws -> OutputType
    typealias AsyncStepBody = (InputType, Handler<OutputType>) -> ()
    
    // Name of the step.
    var name : String?
    // Queue on which to execute the step.
    let executionQueue : dispatch_queue_t!
    // Token, checked on start and on execution.
    var cancellationToken : CancellationToken = CancellationToken()
    // true if token has been marked as cancelled, false if not.
    var isCancelled : Bool { return cancellationToken.cancelled }
    var debugDescription : String {
        if let name = name {
            return "[Step '" + name + "']"
        }
        return "[Step]"
    }
    // Closure body for step.
    let body : StepBody?
    // Async-style body for step
    let asyncBody : AsyncStepBody?
    // Executed when step is resolved.
    var resolveHandler : ((OutputType) -> ())?
    // Executed when step errors.
    var errorHandler : StepErrorHandler?
    // Executed by the final step in a chain, if present.
    var finallyHandler : ((ChainState) -> ())?
    
    init(name: String?, queue: dispatch_queue_t!, body: StepBody) {
        self.name = name
        self.executionQueue = queue
        self.body = body
        self.asyncBody = nil
    }
    
    init(name: String?, queue: dispatch_queue_t!, asyncBody: AsyncStepBody) {
        self.name = name
        self.executionQueue = queue
        self.body = nil
        self.asyncBody = asyncBody
    }
    
    // Starts the step on the target queue.
    func start(input: InputType) {
        if isCancelled { doCancel(); return }
        
        stepwisePrint("Starting \(self) with input: \(input)")
        dispatch_async(executionQueue) {
            if self.isCancelled { self.doCancel(); return }
            
            if let body = self.body {
                do {
                    let output = try body(input)
                    stepwisePrint("Resolved \(self) with output: \(output)")
                    
                    // Calling resolveHandler will clear the finally handler if another step exists in the chain.
                    self.resolveHandler?(output)
                    
                    // If we have a finally handler, execute it.
                    self.finallyHandler?(.Resolved(output))
                } catch {
                    stepwisePrint("\(self) errored: \(error)")
                    self.errorHandler?(error)
                    
                    // If we have a finally handler, execute it.
                    self.finallyHandler?(.Errored(error))
                }
                
            }
            else if let asyncBody = self.asyncBody {
                let handler = Handler<OutputType>(
                    passClosure: { output in
                        stepwisePrint("Resolved \(self) with output: \(output)")
                        
                        // Calling resolveHandler will clear the finally handler if another step exists in the chain.
                        self.resolveHandler?(output)
                        
                        // If we have a finally handler, execute it.
                        self.finallyHandler?(.Resolved(output))
                    },
                    failClosure: { error in
                        stepwisePrint("\(self) errored: \(error)")
                        self.errorHandler?(error)
                        
                        // If we have a finally handler, execute it.
                        self.finallyHandler?(.Errored(error))
                    }
                )
                
                
                asyncBody(input, handler)
            }
        }
    }
    
    // Schedules a new step after this one.
    // Scheduling a new step passes the finally block on.
    func then<Value2>(nextStep: StepNode<OutputType, Value2>) {
        // Scheduling a step overwrites its cancellation token
        nextStep.cancellationToken = self.cancellationToken
        
        // Scheduling a step passes along the finallyHandler. It's cleared on resolve or cancel.
        // We keep it around for now in case this step errors and resolve never happens.
        nextStep.finallyHandler = nextStep.finallyHandler ?? self.finallyHandler
        
        resolveHandler = { [weak self] output in
            let isCancelled = self?.isCancelled ?? false
            if isCancelled { self?.doCancel(); return }
            
            // Pass state through the chain, if present and unset on future steps
            nextStep.cancellationToken = self?.cancellationToken ?? nextStep.cancellationToken
            nextStep.errorHandler = self?.errorHandler ?? nextStep.errorHandler
            nextStep.finallyHandler = nextStep.finallyHandler ?? self?.finallyHandler
            self?.finallyHandler = nil // Can clear here, we're moving on to the next step.
            nextStep.start(output)
        }
    }
    
    // Finalizes the cancellation of this step.
    func doCancel() {
        // Call finally handler, if present.
        self.finallyHandler?(.Canceled(cancellationToken))
        // We must clear the finally handler here, as doCancel() is called from the resolve handler
        // and may be followed by a direct call to the finally handler in Step.resolve().
        // Not clearing here results in a double call.
        self.finallyHandler = nil
        
        if let reason = cancellationToken.reason {
            stepwisePrint("\(self) cancelled with reason: \(reason).")
        }
        else {
            stepwisePrint("\(self) cancelled.")
        }
    }
}