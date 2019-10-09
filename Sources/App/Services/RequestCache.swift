//
//  RequestCache.swift
//  App
//
//  Created by Szymon Lorenz on 22/8/19.
//

import Foundation
import Vapor

final class RequestCache: Service {
    var storage: [String : Any]
    
    init() {
        self.storage = [:]
    }
}

extension Request {
    var storage: [String : Any] {
        get {
            return (try? privateContainer.make(RequestCache.self))?.storage ?? [:]
        }
        set {
            (try? privateContainer.make(RequestCache.self))?.storage = newValue
        }
    }
}
