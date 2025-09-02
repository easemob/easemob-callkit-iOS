//
//  Throttle.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 8/4/25.
//

import Foundation

class RTCCallbackThrottler {
    private var pendingUIDs: Set<UInt> = []
    private var processingTimer: Timer?
    private let batchInterval: TimeInterval = 0.3 // 批处理间隔
    private let maxBatchSize: Int = 5 // 每批最大处理数量
    
    func addUID(_ uid: UInt, completion: @escaping ([UInt]) -> Void) {
        pendingUIDs.insert(uid)
        
        // 如果达到最大批处理大小，立即处理
        if pendingUIDs.count >= maxBatchSize {
            processBatch(completion: completion)
            return
        }
        
        // 重置定时器
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: false) { [weak self] _ in
            self?.processBatch(completion: completion)
        }
    }
    
    private func processBatch(completion: @escaping ([UInt]) -> Void) {
        guard !pendingUIDs.isEmpty else { return }
        
        let uidsToProcess = Array(pendingUIDs)
        pendingUIDs.removeAll()
        processingTimer?.invalidate()
        processingTimer = nil
        
        completion(uidsToProcess)
    }
}



/// A utility class to debounce actions, delaying execution until a specified time interval has passed without further calls.
/// Useful for handling events like rapid successive clicks, executing only the last one after a quiet period.
class Debouncer {
    private let delay: TimeInterval
    private var timer: Timer?
    private let queue: DispatchQueue
    
    /// Initializes the Debouncer.
    /// - Parameters:
    ///   - delay: The time interval to wait before executing the action after the last call (in seconds).
    ///   - queue: The dispatch queue on which to execute the debounced actions. Defaults to main queue.
    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    /// Debounces the given action: schedules it to run after the delay, canceling any previous scheduled action.
    /// - Parameter action: The closure to execute after the debounce delay.
    func debounce(_ action: @escaping () -> Void) {
        // Cancel any existing timer
        timer?.invalidate()
        timer = nil
        
        // Schedule a new timer on the specified queue
        timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            action()
            self.timer = nil
        }
        
        // Ensure the timer runs on the correct queue
        queue.async {
            RunLoop.current.add(self.timer!, forMode: .default)
        }
    }
    
    
}

