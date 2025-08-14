//
//  PropertyWrapper.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 7/31/25.
//

import Foundation


@propertyWrapper public struct CallUserDefault<T> {
    
    let key: String
    let defaultValue: T

    public init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    public var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

