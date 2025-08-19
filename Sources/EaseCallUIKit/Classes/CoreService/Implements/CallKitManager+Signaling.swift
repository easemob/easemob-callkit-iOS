//
//  CallKitManager+Signaling.swift
//  EaseCallUIKit
//
//  Created by 朱继超 on 7/4/25.
//

import Foundation
import AgoraRtcKit

extension CallKitManager: ChatEventsListener {
    
    public func messagesDidReceive(_ aMessages: [ChatMessage]) {
        for message in aMessages {
            if message.chatType == .chat || message.chatType == .groupChat {
                if let ext = message.ext as? [String: Any],!ext.isEmpty {
                    parseCallInfo(from: message)
                }
            }
        }
    }
    
    public func cmdMessagesDidReceive(_ aCmdMessages: [ChatMessage]) {
        for message in aCmdMessages {
            if message.chatType == .chat || message.chatType == .groupChat {
                if let ext = message.ext as? [String: Any],!ext.isEmpty {
                    parseCallInfo(from: message)
                }
            }
        }
    }
    
    private func parseCallInfo(from message: ChatMessage) {
        
        if let ext = message.ext as? [String: Any] {
            guard let msgType = ext[kMsgType] as? String,
                  let callId = ext[kCallId] as? String,
                  let callerDevId = ext[kCallerDevId] as? String
                   else {
                consoleLogInfo("Invalid call info in message id:\(message.messageId) : \(String(describing: message.ext))", type: .error)
                return
            }
            let defaultCalleeId = ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? ""
            let calleeDevId = ext[kCalleeDevId] as? String ?? defaultCalleeId
            let callTypeRawValue = ext[kCallType] as? UInt ?? 0
            let callType = CallType(rawValue: callTypeRawValue) ?? .singleAudio
            let channelName = ext[kChannelName] as? String ?? ""
            let isValid = ext[kCallStatus] as? Bool ?? false//呼叫的离线消息是否有效
            let result = ext[kCallResult] as? String ?? ""
            let callExtension: [String: Any] = ext[kExt] as? [String: Any] ?? [:]
            let groupExtension: [String: Any] = ext[kCallKitGroupExt] as? [String: Any] ?? [:]
            // 解析群组信息
            let groupId = groupExtension["groupId"] as? String ?? ""
            let groupName = groupExtension["groupName"] as? String ?? ""
            let groupAvatar = groupExtension["groupAvatar"] as? String ?? ""
            
            if let userJson = ext[kUserInfo] as? [String: Any] {//解析携带的用户信息
                let profile = CallUserProfile()
                profile.setValuesForKeys(userJson)
                if profile.id.isEmpty {
                    profile.id = message.from
                }
                if CallKitManager.shared.usersCache[profile.id] == nil {
                    CallKitManager.shared.usersCache[profile.id] = profile
                } else {
                    CallKitManager.shared.usersCache[profile.id]?.nickname = profile.nickname
                    CallKitManager.shared.usersCache[profile.id]?.avatarURL = profile.avatarURL
                }
            }
            consoleLogInfo("Received call info from message id:\(message.messageId) from:\(message.from) with ext: \(String(describing: message.ext))", type: .debug)
            if msgType == kMsgTypeValue {
                if let action = ext[kAction] as? String {
                    switch action {
                    case CALL_INVITE://被叫收到邀请
                        handleInviteAction()
                    case CALL_ALERT://主叫收到被叫回复信息判断本次呼叫是否有效
                        handleAlertAction()
                    case CALL_CONFIRM_RING://被叫收到主叫的确认振铃事件后弹窗振铃
                        handleConfirmRingAction()
                    case CALL_CANCEL://被叫收到主叫已经取消呼叫的事件
                        handleCancelAction()
                    case CALL_CONFIRM_CALLEE://确认被叫
                        handleConfirmCalleeAction()
                    case CALL_ANSWER://主叫收到被叫接受/拒绝/忙碌通话
                        handleAnswerCallAction()
                    default:
                        consoleLogInfo("Unknown action type: \(action) in message id:\(message.messageId)", type: .error)
                    }
                    func handleInviteAction() {
                        if let call = self.callInfo,call.callId == callId {
                            consoleLogInfo("Call already in progress with callId: \(callId)", type: .error)
                            return
                        }
                        if GlobalTimerManager.shared.timerCache[callId] != nil {
                            consoleLogInfo("Invitation signal timer already exists for callId: \(callId)", type: .error)
                            return
                        }
                        if ChatClient.shared().currentUsername ?? "" == message.from {
                            return
                        }
                        if let info = self.callInfo,info.state != .idle {
                            self.answerCall(callId: callId, callerId: message.from, result: kBusyResult, callerDeviceId: callerDevId)
                            consoleLogInfo("Call already in progress with callId: \(info.callId) for callId: \(callId)", type: .error)
                        } else {
                            let info = CallInfo(callId: callId, callerId: message.from, callerDeviceId: callerDevId, channelName: channelName, type: callType, startMessageId: message.messageId, extensionInfo: callExtension)
                            info.groupId = groupId
                            info.groupName = groupName
                            info.groupAvatar = groupAvatar
                            info.state = .ringing
                            info.inviteMessage = message
                            self.receivedCalls[callId] = info
                            if UIApplication.shared.applicationState == .background {
                                self.callInfo = info
                                consoleLogInfo("Received call in background with callId: \(callId)", type: .info)
                            }
                            if let calleeId = ChatClient.shared().currentUsername {
                                self.callInfo?.calleeId = calleeId
                                self.callInfo?.calleeDeviceId = ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? ""
                            }
                            self.calleeAnswerCaller(callId: callId, callerId: message.from, callerDeviceId: callerDevId)
                            self.startInvitationSignalTimer(callId: callId)
                        }
                    }
                    
                    func handleAlertAction() {
                        if let call = self.callInfo {
                            if ChatClient.shared().getDeviceConfig(nil).deviceUUID == callerDevId {//主叫回给被叫
                                self.confirmRing(callId: callId, calleeId: message.from, calleeDeviceId: calleeDevId, is_valid: call.callId == callId)
                            } else {
                                consoleLogInfo("Current device:\(call.callerDeviceId) Call accept on other device:\(calleeDevId) messageId:\(message.messageId) ext:\(String(describing: ext))", type: .error)
                            }
                        }
                    }
                    
                    func handleConfirmRingAction() {
                        self.stopInvitationSignalTimer(callId: callId)
                        if let currentDeviceId = ChatClient.shared().getDeviceConfig(nil).deviceUUID, currentDeviceId == calleeDevId {
                            for info in self.receivedCalls.values {
                                self.stopInvitationSignalTimer(callId: info.callId)
                            }
                            if let call = self.callInfo,call.callId != callId,call.state != .idle {
                                self.callerConfirmAnswer(callId: callId, calleeId: message.from, calleeDeviceId: callerDevId, result: kBusyResult)
                                consoleLogInfo("parseCallInfo: Call already in progress with different callId: \(call.callId) for callId: \(callId)", type: .error)
                                return
                            }
                            if calleeDevId == ChatClient.shared().getDeviceConfig(nil).deviceUUID {
                                if let call = self.receivedCalls[callId] {
                                    if isValid {
                                        self.callInfo = call
                                        self.callInfo?.state = .ringing
                                        self.showReceivedCallAlert(call: call)
                                    }
                                    self.receivedCalls.removeAll()
                                }
                            }
                        } else {
                            consoleLogInfo("Current device:\(ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "") Call confirm on other device:\(calleeDevId) messageId:\(message.messageId) ext:\(String(describing: ext))", type: .error)
                        }
                    }
                    
                    func handleCancelAction() {
                        AudioPlayerManager.shared.stopAudio()
                        self.stopInvitationSignalTimer(callId: callId)
                        self.stopConfirmBuildConnectionTimer(callId: callId)
                        self.stopRingTimer(callId: callId)
                        if let call = self.callInfo, call.callId == callId,call.state != .answering {
                            consoleLogInfo("Call canceled with callId: \(callId)", type: .info)
                            self.updateCallEndReason(.remoteCancel)
                        } else {
                            self.receivedCalls.removeValue(forKey: callId)
                        }
                        self.dismissCurrentCallPage()
                    }
                    
                    func handleConfirmCalleeAction() {
                        if let call = self.callInfo {
                            if call.state == .ringing && call.callId == callId {
                                self.callStartTimerStop(callId: callId)
                                self.stopRingTimer(callId: callId)
                                self.stopInvitationSignalTimer(callId: callId)
                                self.stopConfirmBuildConnectionTimer(callId: callId)
                                let currentDeviceId = ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? ""
                                if currentDeviceId == calleeDevId {//确认自己被叫
                                    switch result {
                                    case kAcceptResult:
//                                        if call.type == .singleVideo {
//                                            self.setupLocalVideo()
//                                        }
                                        UIViewController.currentController?.showCallToast(toast: "Connecting".call.localize)
                                        self.joinChannel(channelName: self.callInfo?.channelName ?? "") { [weak self] success in
                                            guard let `self` = self else { return }
                                            if success {
                                                CallKitManager.shared.callInfo?.state = .answering
                                                self.presentCalleeController(call: call)
                                            }
                                            consoleLogInfo("Failed to join channel with error code: \(success)", type: .error)
                                        }
                                    case kBusyResult:
                                        consoleLogInfo("Remote user is busy for callId: \(callId)", type: .info)
                                        self.updateCallEndReason(.busy)
                                    default:
                                        break
                                    }
                                } else {//其它设备处理
                                    consoleLogInfo("Current device:\(currentDeviceId) Call confirm on other device:\(calleeDevId) messageId:\(message.messageId) ext:\(String(describing: ext))", type: .error)
                                    self.updateCallEndReason(.handleOnOtherDevice)
                                    AudioPlayerManager.shared.stopAudio()
                                }
                            } else {
                                self.stopInvitationSignalTimer(callId: callId)
                                self.stopConfirmBuildConnectionTimer(callId: callId)
                                self.receivedCalls.removeValue(forKey: callId)
                            }
                        }
                    }
                    
                    func handleAnswerCallAction() {
                        let deviceId = ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? ""
                        if let call = self.callInfo, deviceId == callerDevId, call.callId == callId {
                            self.stopInvitationSignalTimer(callId: callId)
                            self.stopConfirmBuildConnectionTimer(callId: callId)
                            if call.type == .groupCall {
                                if result != kAcceptResult {
                                    self.itemsCache.removeValue(forKey: message.from)
                                    self.canvasCache.removeValue(forKey: message.from)
                                    if let vc = UIViewController.currentController as? CallMultiViewController {
                                        vc.callView.updateWithItems([message.from])
                                    }
                                }
                            } else {
                                if call.state == .dialing {
                                    if result == kAcceptResult {
                                        self.callInfo?.state = .answering
                                        if self.callVC != nil {
                                            (self.callVC as? Call1v1AudioViewController)?.addCallTimer()
                                            (self.callVC as? Call1v1VideoViewController)?.addCallTimer()
                                        }
                                    } else {
                                        AudioPlayerManager.shared.stopAudio()
                                        let endReason = getEndReason(result: result)
                                        consoleLogInfo("Remote user refuse/busy for callId: \(callId) with reason: \(endReason)", type: .info)
                                        self.updateCallEndReason(endReason)
                                        let result = self.engine?.leaveChannel() ?? 0
                                        consoleLogInfo("Remote user refuse then leave channel result: \(result)", type: .info)
                                        DispatchQueue.main.asyncAfter(wallDeadline: .now()+0.2) {
                                            self.dismissCurrentCallPage()
                                        }
                                    }
                                }
                            }
                            self.callerConfirmAnswer(callId: callId, calleeId: message.from, calleeDeviceId: calleeDevId, result: result)
                        } else {
                            consoleLogInfo("Current device:\(deviceId) Call answer on other device:\(callerDevId) messageId:\(message.messageId) callId:\(callId) call.callId:\(String(describing: self.callInfo?.callId))", type: .error)
                            self.receivedCalls.removeValue(forKey: callId)
                            self.stopInvitationSignalTimer(callId: callId)
                        }
                    }
                }
            }

        }
    }
    
    private func dismissCurrentCallPage() {
        if let currentVC = UIViewController.currentController {
            if currentVC is Call1v1AudioViewController || currentVC is Call1v1VideoViewController {
                currentVC.dismiss(animated: true)
                consoleLogInfo("Dismiss current call page:\(currentVC)", type: .info)
                self.quitCall()
            }
            self.popup?.dismiss()
        }
    }
    
    /// Update the call end reason on the invite message's ext.
    /// - Parameters:
    ///   - reason: The reason for ending the call.``CallEndReason``
    ///   - immediateCallback: If true, the update will immediately notify listeners with the updated message.
    func updateCallEndReason(_ reason: CallEndReason, _ immediateCallback: Bool = true) {
        consoleLogInfo("Update call end reason to: \(reason.rawValue)", type: .info)
        if let info = self.callInfo,let message = info.inviteMessage {
            let ext = message.ext ?? [:]
            var newExt = ext
            newExt[kCallEndReason] = reason.rawValue
            if let duration = self.callInfo?.duration {
                newExt[kCallDuration] = duration
            }
            message.ext = newExt
            Task {
                let result = await ChatClient.shared().chatManager?.update(message)
                if let error = result?.1 {
                    consoleLogInfo("Failed to update call reason:\(reason.rawValue): \(String(describing: error.errorDescription))", type: .error)
                } else {
                    if immediateCallback {
                        for listener in self.listeners.allObjects {
                            listener.didUpdateCallEndReason?(reason: reason, info: info)
                        }
                        self.quitCall()
                    }
                }
            }
        }
    }
    private func showReceivedCallAlert(call: CallInfo) {
        startRingTimer(callId: call.callId)
        AudioPlayerManager.shared.playAudio(from: "ringing")
        var user = self.usersCache[call.callerId]
        if user == nil {
            user = CallUserProfile()
            user?.id = call.callerId
            user?.nickname = call.callerId
        }
        switch UIApplication.shared.applicationState {
        case .active:
            popup = CallPopupView(frame: UIScreen.main.bounds)
            if let profile = user {
                popup?.refresh(profile: profile,type: call.type)
            }
            popup?.show()
            popup?.callCardAction = { [weak self] in
                guard let `self` = self else { return }
                switch $0 {
                case .accept:
                    stopRingTimer(callId: call.callId)
                    if let currentUserId = ChatClient.shared().currentUsername {
                        if self.canvasCache[currentUserId] == nil {
                            let item = CallStreamItem(userId: currentUserId, index: 1, isExpanded: false)
                            item.waiting = false
                            item.uid = self.currentUserRTCUID
                            self.itemsCache[currentUserId] = item
                            let view = CallStreamView(item: item)
                            self.canvasCache[currentUserId] = view
                        }
                    }
                    self.accept()
                case .decline:
                    self.hangup()
                case .other:
                    self.setupLocalVideo()
                    self.callInfo?.state = .ringing
                    self.presentCalleeController(call: call)
                default:
                    break
                }
            }
        case .background:
            if #available(iOS 17.4, *),self.config.enableVOIP {
                LiveCommunicationManager.shared.createConversationManager()
                var uuid = UUID(uuidString: call.callId)
                if uuid == nil {
                    uuid = UUID()
                    consoleLogInfo("[LiveCommunicationManager] new UUID: \(uuid!.uuidString) callId: \(call.callId)", type: .debug)
                } else {
                    consoleLogInfo("[LiveCommunicationManager] reuse UUID: \(uuid!.uuidString)", type: .debug)
                }
                if let liveUUID = uuid {
                    var callerName: String = ""
                    if let profile = user {
                        callerName = profile.nickname
                    }
                    LiveCommunicationManager.shared.reportIncomingCall(uuid: liveUUID, callerName: callerName)
                } else {
                    consoleLogInfo("[LiveCommunicationManager] failed to create UUID", type: .error)
                }
            }
        default:
            break
        }
    }
    
    func presentCalleeController(call: CallInfo) {
        if call.state != .idle {
            var vc: UIViewController = UIViewController()
            switch call.type {
            case .singleAudio:
                vc = Call1v1AudioViewController(role: .callee)
            case .singleVideo:
                vc = Call1v1VideoViewController(role: .callee)
            case .groupCall:
                vc = CallMultiViewController(role: .callee)
            default:
                break
            }
            var root = UIApplication.shared.call.keyWindow?.rootViewController
            if root == nil {
                root = UIApplication.shared.keyWindow?.rootViewController
            }
            root?.present(vc, animated: true)
        }
    }
    
    private func presentCallerPage(call: CallInfo) {
        startRingTimer(callId: call.callId)
        var vc: UIViewController = Call1v1AudioViewController(role: .caller)
        switch call.type {
        case .singleAudio:
            vc = Call1v1AudioViewController(role: .caller)
        case .singleVideo:
            vc = Call1v1VideoViewController(role: .caller)
        case .groupCall:
            vc = CallMultiViewController(role: .caller)
        default:
            break
        }
        DispatchQueue.main.asyncAfter(wallDeadline: .now()+0.25) {
            UIApplication.shared.call.keyWindow?.rootViewController?.present(vc, animated: true)
        }
    }
    
    private func getEndReason(result: String) -> CallEndReason {
        var endReason = CallEndReason.remoteCancel
        switch result {
        case kRefuseResult: endReason = .remoteRefuse
        case kBusyResult: endReason = .busy
        default:
            break
        }
        return endReason
    }
    
    func handleError(_ error: ChatError) {
        self.hangup()
        for listener in self.listeners.allObjects {
            listener.didOccurError?(error: CallError(CallError.IM(error: error), module: .im))
        }
    }
    
    func handleBusinessError(_ error: CallError.CallBusiness) {
        for listener in self.listeners.allObjects {
            listener.didOccurError?(error: CallError(error, module: .business))
        }
    }
}



extension CallKitManager: CallMessageService {
    
    public func addListener(_ listener: any CallServiceListener) {
        if self.listeners.contains(listener) {
            return
        }
        self.listeners.add(listener)
    }
    
    public func removeListener(_ listener: any CallServiceListener) {
        self.listeners.remove(listener)
    }
    
    
    public func call(with userId: String, type: CallType, extensionInfo: [String : Any]? = nil) {
        if self.currentUserInfo == nil {
            if self.profileProvider != nil {
                Task {
                    let profiles = await self.profileProvider?.fetchUserProfiles(profileIds: [userId])
                    if let profile = profiles?.first {
                        self.currentUserInfo = profile
                    } else {
                        consoleLogInfo("Failed to fetch user profile for ID: \(userId)", type: .error)
                        self.handleBusinessError(CallError.CallBusiness(error: .param, message: "Failed to fetch user profile"))
                    }
                }
            }
            if self.profileProviderOC != nil {
                self.profileProviderOC?.fetchProfiles(profileIds: [userId], completion: { profiles in
                    if let profile = profiles.first {
                        self.currentUserInfo = profile
                    } else {
                        consoleLogInfo("Failed to fetch user profile for ID: \(userId)", type: .error)
                        self.handleBusinessError(CallError.CallBusiness(error: .param, message: "Failed to fetch user profile"))
                    }
                })
            }
        }
        if userId.isEmpty {
            consoleLogInfo("User ID cannot be empty", type: .error)
            self.handleBusinessError(CallError.CallBusiness(error: .param, message: "User ID cannot be empty"))
            return
        }
        if userId == ChatClient.shared().currentUsername ?? "" {
            consoleLogInfo("Cannot call yourself", type: .error)
            self.handleBusinessError(CallError.CallBusiness(error: .param, message: "Cannot call yourself"))
            return
        }
        if self.usersCache[userId] == nil {
            let profile = CallUserProfile()
            profile.id = userId
            self.usersCache[userId] = profile
        }
        if type == .groupCall {
            consoleLogInfo("Multi-call requires groupCall", type: .error)
            self.handleBusinessError(CallError.CallBusiness(error: .param, message: "Multi-call requires groupCall"))
            return
        }
        if let call = self.callInfo, !call.callId.isEmpty, call.state != .idle {
            self.handleBusinessError(CallError.CallBusiness(error: .state, message: "A call is already in progress"))
            consoleLogInfo("A call is already in progress: callId:\(call.callId)", type: .error)
            return
        }
        
        // Setup engine first
        let engineError = self.setupEngine()
        if let error = engineError {
            self.handleError(error)
            consoleLogInfo("Failed to setup engine: \(String(describing: error.errorDescription))", type: .error)
            return
        }
        
        // Generate call info first
        let callId = UUID().uuidString
        let channelName = "channel-\(callId)"
        
        // Create CallInfo before showing UI
        self.callInfo = CallInfo(
            callId: callId,
            callerId: ChatClient.shared().currentUsername ?? "",
            callerDeviceId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            channelName: channelName,
            type: type,
            startMessageId: "", // Will be updated after sending message
            extensionInfo: extensionInfo
        )
        self.callInfo?.calleeId = userId
        self.callInfo?.state = .dialing
        
        DispatchQueue.main.async {
            // Setup video scenario
            self.engine?.setVideoScenario(.application1V1Scenario)
            
            // Show call UI first
            var callVC: UIViewController
            if type == .singleVideo {
                self.engine?.startPreview()
                callVC = Call1v1VideoViewController(role: .caller)
            } else {
                callVC = Call1v1AudioViewController(role: .caller)
            }
            
            // Present the call view controller
            UIApplication.shared.call.keyWindow?.rootViewController?.present(callVC, animated: true) { [weak self] in
                guard let `self` = self else { return }
                
                // Setup local video after UI is presented (for video calls)
                if type == .singleVideo {
                    self.setupLocalVideo()
                }
                
                // Play dialing sound
                AudioPlayerManager.shared.playAudio(from: "dialing")
                
                // Now send the signaling message (will join channel after success)
                self.sendCallSignaling(userId: userId, type: type, callId: callId, channelName: channelName, extensionInfo: extensionInfo)
            }
        }
    }

    // New helper method to send signaling
    private func sendCallSignaling(userId: String, type: CallType, callId: String, channelName: String, extensionInfo: [String: Any]?) {
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: CALL_INVITE,
            kCallId: callId,
            kCallType: type.rawValue,
            kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kChannelName: channelName,
            kTs: Int(Date().timeIntervalSince1970 * 1000),
            kCallDuration: 0,
            kCallEndReason: CallEndReason.remoteNoResponse.rawValue
        ]
        
        if extensionInfo != nil {
            ext[kExt] = extensionInfo
        }
        
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        if !json.isEmpty {
            ext.merge(json) { _, new in new }
        }
        
        if self.config.enableVOIP {
            ext[kPush_payload] = ["type":"call"]
            ext[kPush_iOS_payload_apns] = ["em_push_type":"voip"]
        }
        
        let message = ChatMessage(
            conversationID: userId,
            body: ChatTextMessageBody(text: (type == .singleAudio ? "invite_info_audio":"invite_info_video").call.localize),
            ext: ext
        )
        
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                consoleLogInfo("Failed to send call message: \(String(describing: error.errorDescription))", type: .error)
                self.callStartTimerStop(callId: callId)
                
                // Dismiss the UI on failure
                DispatchQueue.main.async {
                    AudioPlayerManager.shared.stopAudio()
                    UIViewController.currentController?.dismiss(animated: true)
                }
                self.quitCall()
                return
            }
            
            // Update call info with message details
            self.callInfo?.inviteMessage = result?.0
            self.callInfo?.extensionInfo = message.ext as? [String : Any]
            
            // Start call timer
            self.callStartTimerStart(callId: callId)
            
            // Join channel after successful signaling
            self.joinChannel(channelName: channelName) { [weak self] success in
                guard let `self` = self else { return }
                if !success {
                    // Handle join channel failure
                    self.callStartTimerStop(callId: callId)
                    DispatchQueue.main.async {
                        AudioPlayerManager.shared.stopAudio()
                        UIViewController.currentController?.dismiss(animated: true)
                        self.callInfo?.state = .idle
                    }
                }
            }
        }
    }
    
    public func groupCall(groupId: String, extensionInfo: [String : Any]? = nil) {
        if groupId.isEmpty {
            consoleLogInfo("group id cannot be empty", type: .error)
            self.handleBusinessError(CallError.CallBusiness(error: .param, message: "Group ID cannot be empty"))
            return
        }
        
        let engineError = self.setupEngine()
        if let error = engineError {
            self.handleError(error)
            consoleLogInfo("Failed to setup engine: \(String(describing: error.errorDescription))", type: .error)
            return
        }
        
        DispatchQueue.main.async {
            guard let currentVC = UIViewController.currentController else {
                consoleLogInfo("No current view controller", type: .error)
                self.handleBusinessError(CallError.CallBusiness(error: .state, message: "No current view controller"))
                return
            }
            
            if currentVC is MultiCallParticipantsController ||
                currentVC.presentedViewController is MultiCallParticipantsController {
                consoleLogInfo("MultiCallParticipantsController is already presented", type: .error)
                self.handleBusinessError(CallError.CallBusiness(error: .state, message: "MultiCallParticipantsController is already presented"))
                return
            }
            
            var excludeUsers: [String] = []
            for item in self.itemsCache.values {
                excludeUsers.append(item.userId)
            }
            if let currentUserId = ChatClient.shared().currentUsername {
                excludeUsers.append(currentUserId)
            }
            currentVC.view.window?.backgroundColor = .black
            (currentVC is CallMultiViewController ? currentVC : UIApplication.shared.call.keyWindow?.rootViewController)?.present(
                MultiCallParticipantsController(groupId: groupId, excludeUsers: excludeUsers, closure: { [weak self] ids,groupName,groupAvatar in
                    guard let `self` = self else { return }
                    if ids.isEmpty {
                        consoleLogInfo("No participants selected for multi-call", type: .error)
                        self.handleBusinessError(CallError.CallBusiness(error: .param, message: "No participants selected for multi-call"))
                        return
                    }
                    if ids.count + excludeUsers.count > 16 {
                        consoleLogInfo("Cannot start multi-call with more than 16 participants", type: .error)
                        self.handleBusinessError(CallError.CallBusiness(error: .param, message: "Cannot start multi-call with more than 16 participants"))
                        return
                    }
                    
                    // Start group call with selected participants
                    self.startGroupCallWithParticipants(
                        ids: ids,
                        groupId: groupId,
                        groupName: groupName,
                        groupAvatar: groupAvatar,
                        extensionInfo: extensionInfo,
                        currentVC: currentVC
                    )

                }), animated: true
            )
        }
    }

    private func startGroupCallWithParticipants(
        ids: [String],
        groupId: String,
        groupName: String?,
        groupAvatar: String?,
        extensionInfo: [String: Any]?,
        currentVC: UIViewController
    ) {
        // Setup user cache
        for id in ids {
            if self.usersCache[id] == nil {
                let profile = CallUserProfile()
                profile.id = id
                self.usersCache[id] = profile
            }
        }
        
        self.engine?.setVideoScenario(.applicationMeetingScenario)
        
        var callId = UUID().uuidString
        var channelName = "channel-\(callId)"
        
        // Handle existing call scenario
        if let call = self.callInfo, !call.callId.isEmpty{
            callId = call.callId
            channelName = call.channelName
            if call.groupId != groupId {
                consoleLogInfo("Call already in progress with different group ID:\(String(describing: call.groupId)) call group:\(groupId)", type: .error)
                self.handleBusinessError(CallError.CallBusiness(error: .state, message: "Call already in progress with different group ID"))
                return
            }
        }
        
        let chatGroup = ChatGroup(id: groupId)
        let group_name = groupName ?? (chatGroup?.groupName ?? "")
        let group_avatar = groupAvatar ?? (chatGroup?.groupAvatar ?? "")
        
        // Create or update CallInfo
        if self.callInfo?.callId.isEmpty ?? true {
            self.callInfo = CallInfo(
                callId: callId,
                callerId: ChatClient.shared().currentUsername ?? "",
                callerDeviceId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
                channelName: channelName,
                type: .groupCall,
                startMessageId: "", // Will be updated after sending message
                extensionInfo: extensionInfo
            )
            
            self.callInfo?.groupId = groupId
            self.callInfo?.groupName = self.callInfo?.groupName ?? group_name
            self.callInfo?.groupAvatar = self.callInfo?.groupAvatar ?? group_avatar
            self.callInfo?.state = .dialing
        } else {
            self.callInfo?.callerId = ChatClient.shared().currentUsername ?? ""
            self.callInfo?.callerDeviceId = ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? ""
        }
        self.callInfo?.type = CallType.groupCall
        // Setup items cache for participants
        DispatchQueue.main.async {
            var lastIndex = 0
            if self.itemsCache.count > 0 {
                lastIndex = self.itemsCache.values.map { $0.index }.max() ?? 0
            }
            
            for (index, id) in ids.enumerated() {
                if self.itemsCache[id] == nil {
                    let item = CallStreamItem(userId: id, index: lastIndex + index + 1, isExpanded: false)
                    item.waiting = true
                    self.itemsCache[id] = item
                    let view = CallStreamView(item: item)
                    self.canvasCache[id] = view
                }
            }
            
            // Show UI first
            if currentVC is CallMultiViewController {
                // Already in multi-call view, just update
                (currentVC as? CallMultiViewController)?.callView.updateWithItems()
                
                // Send signaling (will join channel if needed after success)
                self.sendGroupCallSignaling(
                    ids: ids,
                    callId: callId,
                    channelName: channelName,
                    groupId: groupId,
                    groupName: group_name,
                    groupAvatar: group_avatar,
                    extensionInfo: extensionInfo,
                    isAlreadyInCall: true
                )
            } else {
                // Present new multi-call view
                self.setupLocalVideo()
                let multiCallVC = CallMultiViewController(role: .caller)
                
                UIApplication.shared.call.keyWindow?.rootViewController?.present(multiCallVC, animated: true) {
                    // Play dialing sound after UI is presented
                    AudioPlayerManager.shared.playAudio(from: "dialing")
                    
                    // Send signaling (will join channel after success)
                    self.sendGroupCallSignaling(
                        ids: ids,
                        callId: callId,
                        channelName: channelName,
                        groupId: groupId,
                        groupName: group_name,
                        groupAvatar: group_avatar,
                        extensionInfo: extensionInfo,
                        isAlreadyInCall: false
                    )
                }
            }
        }
    }

    private func sendGroupCallSignaling(
        ids: [String],
        callId: String,
        channelName: String,
        groupId: String,
        groupName: String,
        groupAvatar: String,
        extensionInfo: [String: Any]?,
        isAlreadyInCall: Bool
    ) {
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: CALL_INVITE,
            kCallId: callId,
            kCallType: CallType.groupCall.rawValue,
            kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kChannelName: channelName,
            kTs: Int(Date().timeIntervalSince1970 * 1000),
            kExt: extensionInfo ?? [:],
            kCallKitGroupExt: ["groupId": groupId,
                          "groupName": groupName,
                          "groupAvatar": groupAvatar],
            kCallDuration: 0,
            kCallEndReason: CallEndReason.remoteNoResponse.rawValue
        ]
        
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        if !json.isEmpty {
            ext.merge(json) { _, new in new }
        }
        
        if self.config.enableVOIP {
            ext[kPush_payload] = ["type":"call"]
            ext[kPush_iOS_payload_apns] = ["em_push_type":"voip"]
        }
        
        let message = ChatMessage(
            conversationID: groupId,
            body: ChatTextMessageBody(text: "group_invite_info".call.localize),
            ext: ext
        )
        let receiveList = ids.filter({ $0 != ChatClient.shared().currentUsername ?? "" })
        message.receiverList = receiveList
        message.chatType = .groupChat
        
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                consoleLogInfo("Failed to send group call message: \(String(describing: error.errorDescription))", type: .error)
                self.callStartTimerStop(callId: callId + " users:" + ids.joined(separator: "-"))
                
                // Dismiss UI on failure
                DispatchQueue.main.async {
                    AudioPlayerManager.shared.stopAudio()
                    UIViewController.currentController?.dismiss(animated: true)
                }
                self.quitCall()
                return
            }
            
            // Update call info with message details
            self.callInfo?.inviteMessage = result?.0
            
            // Start timer
            let timerKey = callId + " users:" + ids.joined(separator: "-")
            self.callStartTimerStart(callId: timerKey)
            
            // Join channel after successful signaling (only if not already in call)
            if !isAlreadyInCall {
                self.joinChannel(channelName: channelName) { [weak self] success in
                    guard let `self` = self else { return }
                    if !success {
                        // Handle join channel failure
                        self.callStartTimerStop(callId: timerKey)
                        DispatchQueue.main.async {
                            AudioPlayerManager.shared.stopAudio()
                            self.quitCall()
                        }
                    }
                }
            }
        }
    }

    private func sendGroupCallSignaling(
        ids: [String],
        callId: String,
        channelName: String,
        groupId: String,
        groupName: String,
        groupAvatar: String,
        extensionInfo: [String: Any]?
    ) {
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: CALL_INVITE,
            kCallId: callId,
            kCallType: CallType.groupCall.rawValue,
            kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kChannelName: channelName,
            kTs: Int(Date().timeIntervalSince1970 * 1000),
            kExt: extensionInfo ?? [:],
            kCallKitGroupExt: ["groupId": groupId,
                          "groupName": groupName,
                          "groupAvatar": groupAvatar],
            kCallDuration: 0,
            kCallEndReason: CallEndReason.remoteNoResponse.rawValue
        ]
        
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        if !json.isEmpty {
            ext.merge(json) { _, new in new }
        }
        
        if self.config.enableVOIP {
            ext[kPush_payload] = ["type":"call"]
            ext[kPush_iOS_payload_apns] = ["em_push_type":"voip"]
        }
        
        let message = ChatMessage(
            conversationID: groupId,
            body: ChatTextMessageBody(text: "group_invite_info".call.localize),
            ext: ext
        )
        let receiveList = ids.filter({ $0 != ChatClient.shared().currentUsername ?? "" })
        message.receiverList = receiveList
        message.chatType = .groupChat
        
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                consoleLogInfo("Failed to send group call message: \(String(describing: error.errorDescription))", type: .error)
                self.callStartTimerStop(callId: callId + " users:" + ids.joined(separator: "-"))
                return
            }
            
            // Update call info with message details
            self.callInfo?.inviteMessage = result?.0
            
            // Start timer
            let timerKey = callId + " users:" + ids.joined(separator: "-")
            self.callStartTimerStart(callId: timerKey)
        }
    }
    
    /// Caller answers the call from the callee.
    /// - Parameters:
    ///   - callId: The unique identifier for the call.
    ///   - callerId: The ID of the caller.
    ///   - callerDeviceId: The device ID of the caller.
    public func calleeAnswerCaller(callId: String, callerId: String, callerDeviceId: String) {
        if callId.isEmpty || callerId.isEmpty || callerDeviceId.isEmpty {
            consoleLogInfo("Invalid parameters for calleeAnswerCaller: callId: \(callId), callerId: \(callerId), callerDeviceId: \(callerDeviceId)", type: .error)
            self.handleBusinessError(CallError.CallBusiness(error: .signaling, message: "Invalid parameters for call"))
            return
        }
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: CALL_ALERT,
            kCallId: callId,
            kCallerDevId: callerDeviceId,
            kCalleeDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kTs: Int(Date().timeIntervalSince1970 * 1000) // Timestamp in milliseconds
        ]
        if !json.isEmpty {
            ext.merge(json) { _, new in
                new
            }
        }
        let message = ChatMessage(conversationID: callerId, body: ChatCMDMessageBody(action: kCall), ext: ext)
        message.deliverOnlineOnly = true
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                consoleLogInfo("Failed to send calleeAnswerCaller message: \(String(describing: error.errorDescription))", type: .error)
            }
        }
    }
    
    /// Cancel an ongoing call from caller.
    /// - Parameters:
    ///   - callId: The unique identifier for the call.
    ///   - calleeId: The ID of the callee.
    public func cancelCall(callId: String, calleeId: String) {
        if callId.isEmpty || calleeId.isEmpty {
            consoleLogInfo("Invalid parameters for cancelling call: callId: \(callId), calleeId: \(calleeId)", type: .error)
            self.handleBusinessError(CallError.CallBusiness(error: .signaling, message: "Invalid parameters for cancelling call"))
            return
        }
        self.sendCancelSignal(callId: callId, calleeId: calleeId)
    }
    
    public func sendCancelSignal(callId: String, calleeId: String) {
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: CALL_CANCEL,
            kCallId: callId,
            kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kTs: Int(Date().timeIntervalSince1970 * 1000) // Timestamp in milliseconds
        ]
        if !json.isEmpty {
            ext.merge(json) { _, new in
                new
            }
        }
        let message = ChatMessage(conversationID: calleeId, body: ChatCMDMessageBody(action: kCall), ext: ext)
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                consoleLogInfo("Failed to send cancel call message: \(String(describing: error.errorDescription))", type: .error)
            }
        }
        if let call = self.callInfo,call.callId == callId,call.callerId == ChatClient.shared().currentUsername ?? "" {
            if call.type != .groupCall {
                consoleLogInfo("Caller cancelled the call", type: .info)
                self.updateCallEndReason(.cancel)
            }
        }
    }
    
    /// Confirm the ring for a call from the caller.
    /// - Parameters:
    ///   - callId: The unique identifier for the call.
    ///   - calleeId: The ID of the callee.
    ///   - calleeDeviceId: The device ID of the callee.
    ///   - is_valid: A boolean indicating whether the ring is valid or not.
    public func confirmRing(callId: String,calleeId: String, calleeDeviceId: String, is_valid: Bool) {
        if callId.isEmpty || calleeId.isEmpty || calleeDeviceId.isEmpty {
            consoleLogInfo("Invalid parameters for confirming ring: callId: \(callId), calleeId: \(calleeId), calleeDeviceId: \(calleeDeviceId)", type: .error)
            self.handleBusinessError(CallError.CallBusiness(error: .signaling, message: "Invalid parameters for confirming ring"))
            return
        }
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: CALL_CONFIRM_RING,
            kCallId: callId,
            kCalleeDevId: calleeDeviceId,
            kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kTs: Int(Date().timeIntervalSince1970 * 1000), // Timestamp in milliseconds
            kCallStatus: is_valid ? 1 : 0
        ]
        if !json.isEmpty {
            ext.merge(json) { _, new in
                new
            }
        }
        let message = ChatMessage(conversationID: calleeId, body: ChatCMDMessageBody(action: kCall), ext: ext)
        message.deliverOnlineOnly = true
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                consoleLogInfo("Failed to send confirm ring message: \(String(describing: error.errorDescription))", type: .error)
            }
        }
    }
    
    /// Confirm the answer to a call from the caller.
    /// - Parameters:
    ///   - callId: The unique identifier for the call.
    ///   - calleeId: The ID of the callee.
    ///   - calleeDeviceId: The device ID of the callee.
    ///   - result: The result of the call, such as "accept", "busy", or "refuse".
    public func callerConfirmAnswer(callId: String,calleeId: String,calleeDeviceId: String,result: String) {
        if callId.isEmpty || calleeId.isEmpty || calleeDeviceId.isEmpty || result.isEmpty {
            consoleLogInfo("Invalid parameters for confirming answer: callId: \(callId), calleeId: \(calleeId), calleeDeviceId: \(calleeDeviceId), result: \(result)", type: .error)
            self.handleBusinessError(CallError.CallBusiness(error: .signaling, message: "Invalid parameters for confirming answer"))
            return
        }
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]
        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: CALL_CONFIRM_CALLEE,
            kCallId: callId,
            kCalleeDevId: calleeDeviceId,
            kCallerDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kCallResult: result,
            kTs: Int(Date().timeIntervalSince1970 * 1000) // Timestamp in milliseconds
        ]
        if !json.isEmpty {
            ext.merge(json) { _, new in
                new
            }
        }
        let message = ChatMessage(conversationID: calleeId, body: ChatCMDMessageBody(action: kCall), ext: ext)
        message.deliverOnlineOnly = true
        Task {
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                self.handleError(error)
                consoleLogInfo("Failed to send confirm answer message: \(String(describing: error.errorDescription))", type: .error)
            }
        }
    }
    
    /// Answer an incoming call.
    /// - Parameters:
    ///   - callId: The unique identifier for the call.
    ///   - callerId: The ID of the caller.
    ///   - result: The result of the call, such as "accept", "busy", or "refuse".
    ///   - callerDeviceId: The device ID of the caller.
    func answerCall(callId: String,callerId: String,result: String,callerDeviceId: String) {
        consoleLogInfo("Answer call with ID: \(callId), caller ID: \(callerId), result: \(result), caller device ID: \(callerDeviceId)", type: .info)
        if callId.isEmpty || callerId.isEmpty || result.isEmpty || callerDeviceId.isEmpty {
            consoleLogInfo("Invalid parameters for answering call:\ncallId: \(callId), callerId: \(callerId), result: \(result), callerDeviceId: \(callerDeviceId)", type: .error)
            self.handleBusinessError(CallError.CallBusiness(error: .param, message: "Invalid parameters for answering call"))
            return
        }
        let json = CallKitManager.shared.currentUserInfo?.toJsonObject() ?? [:]

        var ext: [String: Any] = [
            kMsgType: kMsgTypeValue,
            kAction: CALL_ANSWER,
            kCallId: callId,
            kCalleeDevId: ChatClient.shared().getDeviceConfig(nil).deviceUUID ?? "",
            kCallerDevId: callerDeviceId,
            kCallResult: result,
            kTs: Date().timeIntervalSince1970 * 1000, // Timestamp in milliseconds
        ]
        if !json.isEmpty {
            ext.merge(json) { _, new in
                new
            }
        }
        let message = ChatMessage(conversationID: callerId, body: ChatCMDMessageBody(action: kCall), ext: ext)
        message.deliverOnlineOnly = true
        Task {
            if result == kAcceptResult {
                self.startConfirmBuildConnectionTimer(callId: callId)
            }
            let result = await ChatClient.shared().chatManager?.send(message, progress: nil)
            if let error = result?.1 {
                consoleLogInfo("Failed to send answer call message: \(String(describing: error.errorDescription))", type: .error)
                self.handleError(error)
            }
        }
    }
    
    public func hangup() {
        consoleLogInfo("Hangup called", type: .info)
        if let call = self.callInfo {
            AudioPlayerManager.shared.stopAudio()
            switch call.state {
            case .answering:
                self.updateCallEndReason(.hangup)
            case .dialing:
                if call.type == .groupCall {
                    let inviteGroupUserTimerKeys = GlobalTimerManager.shared.timerCache.keys.filter { $0.components(separatedBy: " users:").count > 0 }
                    for key in inviteGroupUserTimerKeys {
                        let keyComponents = key.components(separatedBy: " users:")
                        let callId = keyComponents.first ?? ""
                        
                        if callId.hasSuffix(call.callId) {
                            let users = keyComponents.last?.components(separatedBy: "-") ?? [].filter({ $0 != "start" && $0 != "timer" })
                            for user in users {
                                self.cancelCall(callId: call.callId, calleeId:user)
                            }
                        } else {
                            consoleLogInfo("Group Call Caller Cancel ID mismatch: \(call.callId) != \(callId)", type: .error)
                        }
                    }
                } else {
                    self.cancelCall(callId: call.callId, calleeId:call.calleeId)
                }
                self.updateCallEndReason(.cancel)
            case .ringing:
                self.answerCall(callId: call.callId, callerId: call.callerId, result: kRefuseResult, callerDeviceId: call.callerDeviceId)
                self.updateCallEndReason(.refuse)
            default:
                break
            }
        }
    }
    
    public func accept() {
        AudioPlayerManager.shared.stopAudio()
        if let call = self.callInfo {
            if call.type == .singleVideo {
                self.setupLocalVideo()
//                self.enableLocalVideo(true)
            } else {
                self.enableLocalVideo(false)
            }
            self.answerCall(callId: call.callId, callerId: call.callerId, result: kAcceptResult, callerDeviceId: call.callerDeviceId)
        }
    }
    
    private func convertCallTypeString(_ type: CallType) -> String {
        var callTypeString = ""
        switch type {
        case .singleAudio:
            callTypeString = "singleAudio".call.localize
        case .singleVideo:
            callTypeString = "singleVideo".call.localize
        case .groupCall:
            callTypeString = "multiCall".call.localize
        default:
            break
        }
        return callTypeString
    }
    
    func joinChannel(channelName: String, completion: @escaping ((Bool) -> Void)) {
        self.engine?.enableInstantMediaRendering()
        if let call = self.callInfo,self.hadJoinedChannel {
            let leaveResult = self.engine?.leaveChannel()
            if leaveResult != 0 {
                consoleLogInfo("leaveChannel result: \(String(describing: leaveResult)) channelName:\(channelName)", type: .error)
                self.quitCall()
            }
        }
        
        if self.tokenProvider != nil {
//            if let currentUserId = ChatClient.shared().currentUsername,!currentUserId.isEmpty {
//                self.tokenProvider?.fetchCallToken { [weak self] uid ,token, expiration  in
//                    guard let `self` = self else { return }
//                    if let token = token,!token.isEmpty {
//                        self.token = token
//                        self.tokenExpired = Int64(expiration)
//                        self.joinWithToken(token: self.token, channelName: channelName, uid: uid, completion: completion)
//                    } else {
//                        completion(false)
//                        consoleLogInfo("Failed to fetch call token: \(expiration)", type: .error)
//                    }
//                }
//            } else {
//                consoleLogInfo("Current user ID is empty, cannot fetch call token", type: .error)
//                completion(false)
//            }
        } else {
            if self.token.isEmpty {
                // Fetch the token from the ChatClient
                ChatClient.shared().getRTCToken(withChannel: nil) { [weak self] uid, token, expiration, error in
                    if let error = error {
                        self?.handleError(error)
                        consoleLogInfo("Failed to fetch call token: \(String(describing: error.errorDescription))", type: .error)
                    } else {
                        let rtcToken = token ?? ""
                        self?.token = rtcToken
                        self?.currentUserRTCUID = UInt32(uid)
                        self?.joinWithToken(channelName: channelName, uid: UInt32(uid), completion: completion)
                        consoleLogInfo("Call token fetched successfully: \(String(describing: token))", type: .info)
                    }
                }
            } else {
                self.joinWithToken(channelName: channelName, uid: currentUserRTCUID, completion: completion)
            }
        }
    }
    
    private func joinWithToken(channelName: String, uid: UInt32, completion: @escaping ((Bool) -> Void)) {
        
        let config = AgoraRtcChannelMediaOptions()
        config.autoSubscribeAudio = true
        config.autoSubscribeVideo = true
        config.publishCameraTrack = true
        config.publishMicrophoneTrack = true
        config.clientRoleType = .broadcaster
        config.channelProfile = .liveBroadcasting
        let currentUser = ChatClient.shared().currentUsername ?? ""
        consoleLogInfo("\(currentUser) joining channel: \(channelName) with uid: \(uid) token:\(String(describing: self.token))", type: .debug)
        let result = self.engine?.joinChannel(byToken: self.token, channelId: channelName, uid: UInt(uid), mediaOptions: config, joinSuccess: { [weak self] channel, uid, elapsed in
            guard let `self` = self else { return  }
            consoleLogInfo("\(currentUser) joined channel: \(channel) with uid: \(uid) elapsed: \(elapsed): account \(ChatClient.shared().currentUsername ?? "")", type: .debug)
            DispatchQueue.main.async {
                self.joinedThenPresentCallVC()
            }
            if uid == self.currentUserRTCUID {
                self.hadJoinedChannel = true
                self.updateCallEndReason(.abnormalEnd,false)
            }
            completion(true)
        }) ?? 0
        if result != 0 {
            self.quitCall()
            consoleLogInfo("\(currentUser) failed to join channel: \(channelName) error code: \(result) token:\(String(describing: self.token))", type: .error)
            GlobalTimerManager.shared.invalidate()
            if let code = AgoraErrorCode(rawValue: Int(abs(result))) {
                for listener in self.listeners.allObjects {
                    listener.didOccurError?(error: CallError(CallError.RTC(code: code, message: "RTC error occurred with code: \(result)"), module: .rtc))
                }
            }
            
            completion(false)
        } else {
            consoleLogInfo("\(currentUser) joined channel: \(channelName) result: \(result) token:\(String(describing: self.token))", type: .debug)
        }
    }
    
    private func joinedThenPresentCallVC() {
        UIApplication.shared.isIdleTimerDisabled = true
        if let call = self.callInfo {
            switch call.type  {
            case .singleVideo:
                self.engine?.enableVideo()
            case .singleAudio:
                self.engine?.enableAudio()
            case .groupCall:
                self.setupLocalVideo()
                self.engine?.enableVideo()
                self.enableLocalVideo(false)
            default:
                break
            }
        }
    }
    
    func quitCall() {
        if self.callInfo != nil {
            self.hadJoinedChannel = false
            AudioPlayerManager.shared.playAudio(from: "busy")
            DispatchQueue.main.async {
                AudioPlayerManager.shared.stopAudio()
                UIApplication.shared.isIdleTimerDisabled = false
                if let currentVC = UIViewController.currentController, !(currentVC is Call1v1AudioViewController || currentVC is Call1v1VideoViewController || currentVC is CallMultiViewController) {
                    self.dismissCurrentCallPage()
                }
                self.callVC?.dismiss(animated: false)
                self.callVC = nil
                self.popup?.dismiss()
                FloatingAudioView.removeFromWindow()
            }
            GlobalTimerManager.shared.invalidate()
            
            if #available(iOS 17.4, *),self.config.enableVOIP {
                LiveCommunicationManager.shared.endCall()
            }
            self.isVideoExchanged = false
            let result = self.engine?.leaveChannel()
            consoleLogInfo("quitCall leaveChannel result: \(String(describing: result))", type: .debug)
            self.engine?.stopPreview()
            self.engine?.disableVideo()
            self.engine?.disableAudio()
            self.callInfo?.callId = ""
            self.callInfo?.callerId = ""
            self.callInfo?.callerDeviceId = ""
            self.callInfo?.calleeId = ""
            self.callInfo?.calleeDeviceId = ""
            self.callInfo?.channelName = ""
            self.callInfo?.groupId = nil
            self.callInfo?.groupName = nil
            self.callInfo?.groupAvatar = nil
            self.callInfo?.inviteMessage = nil
            self.cleanUICache()
            self.callInfo?.calleeDeviceId = ""
            self.callInfo?.extensionInfo = nil
            self.callInfo?.state = .idle
            self.callInfo?.duration = 0
            
        }
    }
    
    fileprivate func startInvitationSignalTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-invitation-signal-timer"
        GlobalTimerManager.shared.registerListener(self, timerIdentify: timerIdentify)
    }
    
    func stopInvitationSignalTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-invitation-signal-timer"
        GlobalTimerManager.shared.removeTimeAsSimilarKey(timerIdentify)
        GlobalTimerManager.shared.removeListener(self, timerIdentify: timerIdentify)
        consoleLogInfo("stopInvitationSignalTimer", type: .debug)
    }
    
    fileprivate func startConfirmBuildConnectionTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-confirm-build-connection-timer"
        GlobalTimerManager.shared.registerListener(self, timerIdentify: timerIdentify)
    }
    
    func stopConfirmBuildConnectionTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-confirm-build-connection-timer"
        GlobalTimerManager.shared.removeTimeAsSimilarKey(timerIdentify)
        GlobalTimerManager.shared.removeListener(self, timerIdentify: timerIdentify)
        consoleLogInfo("stopConfirmBuildConnectionTimer", type: .debug)
    }
    
    func startRingTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-ring-timer"
        GlobalTimerManager.shared.registerListener(self, timerIdentify: timerIdentify)
    }
    
    func stopRingTimer(callId: String) {
        let timerIdentify = "call-\(callId)-start-ring-timer"
        GlobalTimerManager.shared.removeTimeAsSimilarKey(timerIdentify)
        GlobalTimerManager.shared.removeListener(self, timerIdentify: timerIdentify)
        consoleLogInfo("stopRingTimer", type: .debug)
    }
    
    fileprivate func callStartTimerStart(callId: String) {
        let timerIdentify = "call-\(callId)-start-timer"
        GlobalTimerManager.shared.registerListener(self, timerIdentify: timerIdentify)
    }
    
    func callStartTimerStop(callId: String) {
        let timerIdentify = "call-\(callId)-start-timer"
        GlobalTimerManager.shared.removeTimeAsSimilarKey(timerIdentify)
        GlobalTimerManager.shared.removeListener(self, timerIdentify: timerIdentify)
    }
}

//MARK: - Time changed
extension CallKitManager: TimerServiceListener {
    public func timeChanged(_ timerIdentify: String, interval seconds: UInt) {
        guard let call = self.callInfo else { return }
        print("CallKitManager timeChanged: \(timerIdentify) seconds: \(seconds)")
        let startInvitationSignalTimer = "call-\(call.callId)-start-invitation-signal-timer"
        let startConfirmBuildConnectionTimer = "call-\(call.callId)-start-confirm-build-connection-timer"
        let callStartTimerKey = "call-\(call.callId)-start-timer"
        let timerIdentifyRing = "call-\(call.callId)-start-ring-timer"
        let answeringTimerKey = "call-\(call.channelName)-answering-timer"
        switch timerIdentify {
        case callStartTimerKey://主叫呼出等待超时
            if seconds >= CallKitManager.shared.config.ringTimeOut {
                self.callStartTimerStop(callId: call.callId)
                //主叫方发cancel
                self.cancelCall(callId: call.callId, calleeId: call.calleeId)
                if let vc = UIViewController.currentController {
                     if vc is Call1v1AudioViewController || vc is Call1v1VideoViewController {
                        vc.dismiss(animated: true)
                    }
                }
                if FloatingAudioView.isFloatingViewVisible() {
                    FloatingAudioView.removeFromWindow()
                }
                self.popup?.dismiss()
                consoleLogInfo("Caller call timeout, cancel the call", type: .info)
                self.updateCallEndReason(.remoteNoResponse)
            }
        case timerIdentifyRing://被叫振铃等待超时
            if seconds >= CallKitManager.shared.config.ringTimeOut {
                self.stopRingTimer(callId: call.callId)
                self.ringTimeout()
                if let vc = UIViewController.currentController {
                     if vc is Call1v1AudioViewController || vc is Call1v1VideoViewController {
                        vc.dismiss(animated: true)
                    }
                }
                if FloatingAudioView.isFloatingViewVisible() {
                    FloatingAudioView.removeFromWindow()
                }
                self.popup?.dismiss()
            }
        case startInvitationSignalTimer://开始邀请回复信令超时
            if seconds >= updateDuration,call.calleeId == ChatClient.shared().currentUsername ?? "" {
                consoleLogInfo("Callee invitation signal timeout, no response", type: .info)
                self.updateCallEndReason(.noResponse)
                self.stopInvitationSignalTimer(callId: call.callId)
                AudioPlayerManager.shared.stopAudio()
            }
        case startConfirmBuildConnectionTimer://建立链接超时
            if seconds >= updateDuration {
                self.stopConfirmBuildConnectionTimer(callId: call.callId)
                AudioPlayerManager.shared.stopAudio()
                consoleLogInfo("Callee confirm build connection timeout, no response", type: .info)
                self.updateCallEndReason(.remoteNoResponse)
            }
        case answeringTimerKey://更新时间
            if call.state == .answering {
                self.callInfo?.duration = seconds
                if let floating = UIApplication.shared.call.keyWindow?.viewWithTag(floatingViewTag) as? FloatingAudioView,!floating.isHidden {
                    floating.updateSeconds(seconds: Int(seconds))
                }
                if seconds%updateDuration == 0 {
                    if let message = self.callInfo?.inviteMessage {
                        let ext = message.ext ?? [:]
                        var newExt = ext
                        newExt[kCallDuration] = seconds
                        message.ext = newExt
                        Task {
                            let result = await ChatClient.shared().chatManager?.update(message)
                            if let error = result?.1 {
                                consoleLogInfo("Failed to update call duration: \(String(describing: error.errorDescription))", type: .error)
                            }
                        }
                    }
                }
            }
            
        default:
            if timerIdentify.contains(" users:") {//群组中发起通话邀请成员超时
                if seconds >= CallKitManager.shared.config.ringTimeOut {
                    if call.type == .groupCall {
                        if let currentVC = UIViewController.currentController as? CallMultiViewController {
                            let inviteGroupUserTimerKeys = GlobalTimerManager.shared.timerCache.keys.filter { $0.components(separatedBy: " users:").count > 0 }
                            var removeUsers: [String] = []
                            for key in inviteGroupUserTimerKeys {
                                if timerIdentify == key,seconds >= CallKitManager.shared.config.ringTimeOut {
                                    var users = key.components(separatedBy: " users:").last?.components(separatedBy: "-") ?? []
                                    users.removeAll { $0 == "start" || $0 == "timer" }
                                    for userId in users {
                                        if let item = self.itemsCache[userId],item.waiting {
                                            removeUsers.append(userId)
                                            self.itemsCache.removeValue(forKey: userId)
                                            self.canvasCache.removeValue(forKey: userId)
                                            self.cancelCall(callId: call.callId, calleeId: userId)
                                        }
                                    }
                                }
                            }
                            if !removeUsers.isEmpty {
                                currentVC.callView.updateWithItems(removeUsers)
                            }
                            GlobalTimerManager.shared.removeTimeAsSimilarKey(timerIdentify)
                        }
                    }
                }
            }
            
            break
        }
    }
    
    
}
