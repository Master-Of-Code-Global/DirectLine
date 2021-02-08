//
//  PublishersExtension.swift
//  
//
//  Created by Andrii Horishnii on 11.02.2021.
//

import Foundation
import Combine

extension Publishers {
    struct RetryIf<P: Publisher>: Publisher {
        typealias Output = P.Output
        typealias Failure = P.Failure
        
        let publisher: P
        let times: Int
        let condition: (P.Failure) -> Bool
                
        func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            guard times > 0 else { return publisher.receive(subscriber: subscriber) }
            
            publisher.catch { (error: P.Failure) -> AnyPublisher<Output, Failure> in
                if condition(error)  {
                    return RetryIf(publisher: publisher, times: times - 1, condition: condition).eraseToAnyPublisher()
                } else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }.receive(subscriber: subscriber)
        }
    }
}

extension Publisher {
    func retry(_ times: Int, if condition: @escaping (Failure) -> Bool) -> Publishers.RetryIf<Self> {
        Publishers.RetryIf(publisher: self, times: times, condition: condition)
    }
}
