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

@propertyWrapper
public final class CallAtomicUnfairLock<T> {
    private var value: T
    private var lock = os_unfair_lock()
    
    // 初始化时设置初始值
    public init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    // 包装的属性值，自动处理加锁解锁
    public var wrappedValue: T {
        get {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return value
        }
        set {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            value = newValue
        }
    }

    public var projectedValue: CallAtomicUnfairLock<T> { self }
    
    /// 原子性修改操作
    /// - Parameter transform: 对值进行修改的闭包
    public func modify<Result>(_ transform: (inout T) throws -> Result) rethrows -> Result {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return try transform(&value)
    }
    
    /// 原子性读取并处理值
    /// - Parameter transform: 处理值的闭包，返回处理结果
    /// - Returns: 处理结果
    public func withValue<Result>(_ transform: (T) throws -> Result) rethrows -> Result {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return try transform(value)
    }
}

extension CallAtomicUnfairLock: @unchecked Sendable where T: Sendable {}
