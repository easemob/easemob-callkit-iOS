//
//  CallKitManager+RTC.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 7/4/25.
//

import Foundation
import AgoraRtcKit


extension CallKitManager: CallServiceAction {
    
    func getUserInfo(userId: String) -> AgoraUserInfo? {
        var errorCode: AgoraErrorCode = .noError // Initialize with default success value
        if let userInfo = withUnsafeMutablePointer(to: &errorCode, { errorPtr in
            self.engine?.getUserInfo(byUserAccount: userId, withError: errorPtr)
        }) {
            if errorCode == .noError {
                return userInfo
            } else {
                consoleLogInfo("getUid failed with error: \(errorCode.rawValue)", type: .error)
                return nil
            }
        }
        return nil
    }
    
    func switchCamera() {
        let result = self.engine?.switchCamera()
        consoleLogInfo("switchCamera result: \(String(describing: result))", type: .debug)
    }
    func turnSpeakerOn(on: Bool) {
        let result = self.engine?.setEnableSpeakerphone(on)
        consoleLogInfo("setEnableSpeakerphone result: \(String(describing: result))", type: .debug)
    }

    func enableLocalAudio(_ enable: Bool) {
        let result = self.engine?.muteLocalAudioStream(!enable)
        consoleLogInfo("muteLocalAudioStream result: \(String(describing: result))", type: .debug)
    }
    
    func enableLocalVideo(_ enable: Bool) {
        let previewResult = enable == true ? self.engine?.startPreview() : self.engine?.stopPreview()
        let result = self.engine?.muteLocalVideoStream(!enable)
        consoleLogInfo("muteLocalVideoStream result: \(String(describing: result)) previewResult:\(String(describing: previewResult))", type: .debug)
    }
    
    func setupLocalVideo() {
        let cameraConfig = AgoraCameraCapturerConfiguration()
        cameraConfig.cameraDirection = .front
        self.engine?.setCameraCapturerConfiguration(cameraConfig)
        self.engine?.enableVideo()
        self.engine?.enableAudio()
        if let call = self.callInfo {
            if call.type == .multiCall {
                let canvas = AgoraRtcVideoCanvas()
                canvas.uid = 0
                canvas.renderMode = .hidden
                if let currentUserId = ChatClient.shared().currentUsername,!currentUserId.isEmpty {
                    let item = CallStreamItem(userId: currentUserId, index: 0, isExpanded: false)
                    self.itemsCache[currentUserId] = item
                    let view = CallStreamView(item: item)
                    self.canvasCache[currentUserId] = view
                    canvas.view = view.canvasView
                }
                self.engine?.setupLocalVideo(canvas)
            }
        }
        
    }
    
    func setupRemoteVideoView(userId: String,uid: UInt) {
        guard let engine = self.engine else {
            consoleLogInfo("setupRemoteVideoView failed, engine is nil", type: .error)
            return
        }
        
        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = uid
        canvas.renderMode = .hidden
        if let call = self.callInfo {
            if call.type == .multiCall {
                if let streamView = self.canvasCache[userId] {
                    canvas.view = streamView.canvasView
                } else {
                    let item = CallStreamItem(userId: userId, index: 1, isExpanded: false)
                    item.videoMuted = false
                    let view = CallStreamView(item: item)
                    self.canvasCache[userId] = view
                    canvas.view = view.canvasView
                    for listener in self.listeners.allObjects {
                        listener.remoteUserDidJoined?(item: view.item)
                    }
                }
                engine.setupRemoteVideo(canvas)
            }
        }
    }
}

extension CallKitManager: AgoraRtcEngineDelegate {
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        consoleLogInfo("rtcEngine didOccurError: \(errorCode.rawValue)", type: .error)
        for listener in self.listeners.allObjects {
            listener.didOccurError?(CallError.error(code: errorCode.rawValue, message: "AgoraRtcEngineKit error occurred: \(errorCode.rawValue)"))
        }
        switch errorCode {
        case .tokenExpired,.invalidToken:
            DispatchQueue.main.async {
                let controller = UIViewController.currentController
                if controller is Call1v1AudioViewController || controller is Call1v1VideoViewController || controller is CallMultiViewController {
                    // If the current controller is a call view, dismiss it
                    controller?.dismiss(animated: true, completion: nil)
                    self.quitCall()
                }
                self.popup?.dismiss()
            }
        default:
            break
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        
        
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        if let channelName = self.callInfo?.channelName,let userId = ChatClient.shared().currentUsername {
            consoleLogInfo("rtcEngine tokenPrivilegeWillExpire for channel: \(channelName) userId: \(userId)", type: .debug)
            if self.tokenProvider != nil,self.tokenProviderOC == nil {
                Task {
                    let tuple = await self.tokenProvider?.fetchCallToken(channelName: channelName, userId: userId)
                    if let token = tuple?.0, let expire = tuple?.1, !token.isEmpty {
                        let result = engine.renewToken(token)
                        consoleLogInfo("rtcEngine renewToken: \(token) result: \(String(describing: result))", type: .debug)
                    } else {
                        consoleLogInfo("rtcEngine renewToken failed to fetch new token", type: .error)
                    }
                }
            }
            if self.tokenProvider == nil,self.tokenProviderOC != nil {
                self.tokenProviderOC?.fetchCallToken(channelName: channelName, userId: userId, completion: { token, expire in
                    if let token = token, !token.isEmpty {
                        let result = engine.renewToken(token)
                        consoleLogInfo("rtcEngine renewToken: \(token) result: \(String(describing: result))", type: .debug)
                    } else {
                        consoleLogInfo("rtcEngine renewToken failed to fetch new token", type: .error)
                    }
                })
            }
        }
        
        
    }
    
    public func rtcEngineRequestToken(_ engine: AgoraRtcEngineKit) {
        if let channelName = self.callInfo?.channelName,let userId = ChatClient.shared().currentUsername {
            consoleLogInfo("rtcEngine tokenPrivilegeWillExpire for channel: \(channelName) userId: \(userId)", type: .debug)
            if self.tokenProvider != nil,self.tokenProviderOC == nil {
                Task {
                    let tuple = await self.tokenProvider?.fetchCallToken(channelName: channelName, userId: userId)
                    if let token = tuple?.0, let expire = tuple?.1, !token.isEmpty {
                        let result = self.joinChannel(channelName: channelName)
                        consoleLogInfo("rtcEngine renewToken: \(token) result: \(String(describing: result))", type: .debug)
                    } else {
                        consoleLogInfo("rtcEngine renewToken failed to fetch new token", type: .error)
                    }
                }
            }
            if self.tokenProvider == nil,self.tokenProviderOC != nil {
                self.tokenProviderOC?.fetchCallToken(channelName: channelName, userId: userId, completion: { token, expire in
                    if let token = token, !token.isEmpty {
                        let result = self.joinChannel(channelName: channelName)
                        consoleLogInfo("rtcEngine renewToken: \(token) result: \(String(describing: result))", type: .debug)
                    } else {
                        consoleLogInfo("rtcEngine renewToken failed to fetch new token", type: .error)
                    }
                })
            }
        }
    }
    
    func getStreamRenderQuality(with count: UInt) -> AgoraVideoStreamType {
        var type = AgoraVideoStreamType.low
        switch count {
        case 1...2: type = .high
        case 3...4: type = .layer1
        case 5...6: type = .layer2
        case 7...8: type = .layer3
        case 9...10: type = .layer4
        case 11...12: type = .layer5
        case 13...14: type = .layer6
        case 15...: type = .low
        default:
            break
        }
        return type
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        DispatchQueue.main.async {
            if let call = self.callInfo {
                if call.type == .multiCall {
                    //设置本地渲染远端流的质量
                    var type = self.getStreamRenderQuality(with: UInt(self.canvasCache.count))
                    
                    var errorCode: AgoraErrorCode = .noError // Initialize with default success value
                    let userInfo = withUnsafeMutablePointer(to: &errorCode) { errorPtr in
                        engine.getUserInfo(byUid: uid, withError: errorPtr)
                    }
                    
                    if errorCode != .noError {
                        consoleLogInfo("remote user didJoinedOfUid rtcEngine getUserInfo failed with error: \(errorCode.rawValue)", type: .error)
                        return
                    }
                    if let userId = userInfo?.userAccount,userId != ChatClient.shared().currentUsername,!userId.isEmpty {
                        if self.canvasCache[userId] == nil {
                            let item = CallStreamItem(userId: userId, index: 1, isExpanded: false)
                            item.waiting = false
                            self.itemsCache[userId] = item
                            let view = CallStreamView(item: item)
                            self.canvasCache[userId] = view
                            for listener in self.listeners.allObjects {
                                listener.remoteUserDidJoined?(item: view.item)
                            }
                            if let currentVC = UIViewController.currentController as? CallMultiViewController {
                                currentVC.callView.updateWithItems()
                            }
                        } else {
                            if let streamView = self.canvasCache[userId],let item = self.itemsCache[userId] {
                                item.waiting = false
                                streamView.updateItem(item)
                            }
                        }
                        
                    }
                    if let uid = userInfo?.uid,uid != 0 {
                        engine.setRemoteVideoStream(uid, type: type)
                    }
                } else {
                    //单人通话
                    if let controller = UIViewController.currentController as? Call1v1VideoViewController {
                        controller.addCallTimer()
                    }
                    if let controller = UIViewController.currentController as? Call1v1AudioViewController {
                        controller.addCallTimer()
                    }
                }
                self.stopRingTimer(callId: call.callId)
            }
        }
        
        consoleLogInfo("rtcEngine didJoinedOfUid: \(uid) elapsed: \(elapsed)", type: .debug)
        
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        consoleLogInfo("rtcEngine didJoinChannel: \(channel) withUid: \(uid) elapsed: \(elapsed)", type: .debug)
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        var errorCode: AgoraErrorCode = .noError
        let userInfo = withUnsafeMutablePointer(to: &errorCode) { errorPtr in
            engine.getUserInfo(byUid: uid, withError: errorPtr)
        }
        let userID = userInfo?.userAccount ?? ""
        consoleLogInfo("rtcEngine didOfflineOfUid: \(uid) userId:\(userID) reason: \(reason.rawValue)", type: .debug)
        DispatchQueue.main.async {
            if let call = self.callInfo {
                if call.type != .multiCall {
                    switch reason {
                    case .dropped:
                        self.updateCallEndReason(.abnormalEnd)
                        //TODO: - 是否发送信令消息给对方告知通话异常结束
                    case .quit:
                        self.updateCallEndReason(.hangup)
                    default:
                        break
                    }
                    let result = engine.leaveChannel()
                    consoleLogInfo("rtcEngine didOfflineOfUid leaveChannel result: \(String(describing: result))", type: .debug)
                    self.quitCall()
                    UIViewController.currentController?.dismiss(animated: true)
                } else {
                    self.callInfo?.state = .answering
                    if let currentVC = UIViewController.currentController as? CallMultiViewController {
                        if let streamView = self.canvasCache[userID],let item = self.itemsCache[userID] {
                            streamView.removeFromSuperview()
                            self.canvasCache.removeValue(forKey: userID)
                            self.itemsCache.removeValue(forKey: userID)
                            for listener in self.listeners.allObjects {
                                listener.remoteUserDidLeft?(userId: item.userId)
                            }
                        }
                        currentVC.callView.updateWithItems([userID])
                    }
                }
            }
        }
    }
    
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, remoteVideoStateChangedOfUid uid: UInt, state: AgoraVideoRemoteState, reason: AgoraVideoRemoteReason, elapsed: Int) {
        
        DispatchQueue.main.async {
            var errorCode: AgoraErrorCode = .noError
            let userInfo = withUnsafeMutablePointer(to: &errorCode) { errorPtr in
                engine.getUserInfo(byUid: uid, withError: errorPtr)
            }
            guard let userId = userInfo?.userAccount else {
                consoleLogInfo("rtcEngine remoteVideoStateChangedOfUid: \(uid) failed to get userId with error: \(errorCode.rawValue)", type: .error)
                return
            }
            if let call = self.callInfo {
                switch state {
                case .starting:
                    consoleLogInfo("remoteVideoStateChangedOfUid: \(uid) userId:\(userId) state: starting", type: .debug)
                    if call.type == .multiCall {
                        if let streamView = self.canvasCache[userId],let item = self.itemsCache[userId] {
                            if reason == .remoteUnmuted {
                                item.videoMuted = false
                            }
                            streamView.updateItem(item)
                            self.setupRemoteVideoView(userId: userId, uid: uid)
                            
                        }
                    }
                    if call.type == .singleVideo {
                        if let controller = UIViewController.currentController as? Call1v1VideoViewController {
                            if reason == .remoteUnmuted {
                                controller.floatView.updateVideoState(false)
                            }
                        } else {
                            if let controller = self.callVC as? Call1v1VideoViewController {
                                if reason == .remoteUnmuted {
                                    controller.floatView.updateVideoState(false)
                                }
                            }
                        }
                    }
                case .stopped:
                    if call.type == .multiCall {
                        if let streamView = self.canvasCache[userId],let item = self.itemsCache[userId] {
                            if reason == .remoteMuted {
                                item.videoMuted = true
                            }
                            streamView.updateItem(item)
                            
                        }
                    }
                    if call.type == .singleVideo {
                        if let controller = UIViewController.currentController as? Call1v1VideoViewController {
                            if reason == .remoteMuted {
                                controller.floatView.updateVideoState(true)
                            }
                        } else {
                            if let controller = self.callVC as? Call1v1VideoViewController {
                                if reason == .remoteMuted {
                                    controller.floatView.updateVideoState(true)
                                }
                            }
                        }
                    }
                default:
                    break
                }
            }
            consoleLogInfo("rtcEngine remoteVideoStateChangedOfUid: \(uid) userId:\(userId) elapsed:\(elapsed) state: \(state.rawValue) reason: \(reason.rawValue)", type: .debug)
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioMuted muted: Bool, byUid uid: UInt) {
        DispatchQueue.main.async {
            var errorCode: AgoraErrorCode = .noError
            let userInfo = withUnsafeMutablePointer(to: &errorCode) { errorPtr in
                engine.getUserInfo(byUid: uid, withError: errorPtr)
            }
            let userId = userInfo?.userAccount ?? ""
            if !userId.isEmpty {
                if let call = self.callInfo {
                    if call.type == .multiCall {
                        if let streamView = self.canvasCache[userId],let item = self.itemsCache[userId] {
                            item.audioMuted = muted
                            streamView.updateItem(item)
                            
                        }
                    }
                    if call.type == .singleVideo {
                        if let controller = UIViewController.currentController as? Call1v1VideoViewController {
                            controller.callView.micView.isHidden = true
                            if self.isVideoExchanged {
                                if muted {
                                    controller.micView.isHidden = false
                                    controller.floatView.updateAudioState(!muted)
                                } else {
                                    controller.micView.isHidden = true
                                    controller.floatView.updateAudioState(muted)
                                }
                            } else {
                                controller.micView.isHidden = true
                                controller.floatView.updateAudioState(muted)
                            }
                        } else {
                            if let controller = self.callVC as? Call1v1VideoViewController {
                                controller.callView.micView.isHidden = true
                                if self.isVideoExchanged {
                                    if muted {
                                        controller.micView.isHidden = false
                                        controller.floatView.updateAudioState(!muted)
                                    } else {
                                        controller.micView.isHidden = true
                                        controller.floatView.updateAudioState(muted)
                                    }
                                } else {
                                    controller.micView.isHidden = true
                                    controller.floatView.updateAudioState(muted)
                                }
                            }
                        }
                    }
                }
            }
            consoleLogInfo("rtcEngine didAudioMuted: \(muted) byUid: \(uid) userId:\(userId)", type: .debug)
        }
        
        
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        for speaker in speakers {
//            self.canvasCache[]
            var errorCode: AgoraErrorCode = .noError // Initialize with default success value
            let userInfo = withUnsafeMutablePointer(to: &errorCode) { errorPtr in
                engine.getUserInfo(byUid: speaker.uid, withError: errorPtr)
            }
//            userInfo?.userAccount
//            info?.userAccount
            //TODO: - update user mic icon on multi call
        }
        
    }
}

extension CallKitManager: AgoraVideoFrameDelegate {
    public func onCapture(_ videoFrame: AgoraOutputVideoFrame, sourceType: AgoraVideoSourceType) -> Bool {
        if let call = self.callInfo {
            if call.type == .singleVideo {
                if let controller = UIViewController.currentController as? Call1v1VideoViewController, let pixelBuffer = videoFrame.pixelBuffer {
                        controller.callView.renderVideoPixelBuffer(pixelBuffer: pixelBuffer, width: videoFrame.width, height: videoFrame.height)
                }
            }
        }
        return true
    }
    
    public func onRenderVideoFrame(_ videoFrame: AgoraOutputVideoFrame, uid: UInt, channelId: String) -> Bool {
        if let call = self.callInfo {
            if call.type == .singleVideo {
                if let controller = UIViewController.currentController as? Call1v1VideoViewController{
                    if let pixelBuffer = videoFrame.pixelBuffer {
                        controller.floatView.renderVideoPixelBuffer(pixelBuffer: pixelBuffer, width: videoFrame.width, height: videoFrame.height)
                    } else {
                        controller.floatView.renderFromVideoFrameData(videoData: videoFrame)
                    }
                } else {
                    if let controller = self.callVC as? Call1v1VideoViewController {
                        if let pixelBuffer = videoFrame.pixelBuffer {
                            controller.floatView.renderVideoPixelBuffer(pixelBuffer: pixelBuffer, width: videoFrame.width, height: videoFrame.height)
                        } else {
                            controller.floatView.renderFromVideoFrameData(videoData: videoFrame)
                        }
                    }
                }
            }
        }
        return true
    }
    
    public func exchangeVideoFrame() -> Bool {
        // 防止重复操作
        guard UIViewController.currentController is Call1v1VideoViewController else {
            return false
        }
        
        // 切换状态
        isVideoExchanged.toggle()
        return true
    }
    
    // 重置到默认状态
    public func resetVideoExchange() {
        if isVideoExchanged {
            _ = exchangeVideoFrame()
        }
    }

}
