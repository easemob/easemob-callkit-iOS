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

